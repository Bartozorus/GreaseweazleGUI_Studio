# Comparateur de secteurs compile a la volee (boucle PowerShell trop lente sur 900 Ko)
$script:FastCompare = $false
try {
    Add-Type -TypeDefinition @'
public static class GwCompare {
    public static int[] DiffSectors(byte[] a, byte[] b, int sectorSize) {
        var list = new System.Collections.Generic.List<int>();
        int n = System.Math.Max(a.Length, b.Length);
        int sectors = (n + sectorSize - 1) / sectorSize;
        for (int sIdx = 0; sIdx < sectors; sIdx++) {
            int start = sIdx * sectorSize;
            int end = System.Math.Min(start + sectorSize, n);
            for (int i = start; i < end; i++) {
                if (i >= a.Length || i >= b.Length || a[i] != b[i]) { list.Add(sIdx); break; }
            }
        }
        return list.ToArray();
    }
    public static long DiffBytes(byte[] a, byte[] b) {
        long d = 0; int n = System.Math.Max(a.Length, b.Length);
        for (int i = 0; i < n; i++) { if (i >= a.Length || i >= b.Length || a[i] != b[i]) d++; }
        return d;
    }
}
'@ -ErrorAction Stop
    $script:FastCompare = $true
} catch { }

# Analyse de flux SCP compilee (onglet Alignement)
$script:ScpStatsOk = $false
try {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
public class ScpRev {
    public double IndexMs; public int NFlux; public double Cell;
    public double Jitter; public double R3; public double R4;
    public int OutOfClass; public int Dropouts;
    public double Shift; public int ShiftN;   // decalage de pic residuel (ns, > 0 = sous-compense) et effectif minimal
    public double ShiftSE;                    // erreur-type du decalage (ns), d apres la dispersion dans les quatre contextes
    public int NSL, NSS, NLS, NLL;            // effectifs : 2T entre deux longs / deux courts, 3T entre deux courts / deux longs
    public int Blocks, Unstable, MaxRun;      // stabilite d un tour a l autre (premier tour) : blocs, blocs instables, plus longue suite
    public int RunPos = -1;                   // debut de cette suite, en pour mille du tour
    public string[] Finger; public int Rich;  // empreinte de la piste (reconnaissance de l original) et nombre de blocs riches
}
public static class ScpStats {
    public static ScpRev Analyze(int[] flux, double indexNs) { return Analyze(flux, indexNs, 0); }
    // cellsPerRev > 0 : motif connu (calibration) -> cellule = duree du tour / nombre de cellules. La mediane des
    // intervalles de deux cellules derive sinon quand le decalage residuel est grand, et fait sortir des intervalles
    // de leur classe (simulation : jusqu a +37 ns sur le decalage mesure a 200 ns de precomp).
    public static ScpRev Analyze(int[] flux, double indexNs, int cellsPerRev) {
        var r = new ScpRev(); r.IndexMs = indexNs / 1e6; r.NFlux = flux.Length; r.Shift = double.NaN; r.ShiftN = 0; r.ShiftSE = double.NaN;
        // 1) estimation de la cellule : mediane des intervalles de 2 cellules.
        //    Fenetre large (3,0 - 5,0 us) valable pour 2 us (AmigaDOS) comme pour 1,89 us (long tracks).
        var c2raw = new List<double>();
        foreach (int f in flux) if (f > 3000 && f < 5000) c2raw.Add(f);
        if (c2raw.Count < 50) { r.Cell = double.NaN; r.Jitter = double.NaN; r.R3 = double.NaN; r.R4 = double.NaN; r.OutOfClass = flux.Length; r.Dropouts = 0; return r; }
        c2raw.Sort(); double cell = (cellsPerRev > 0 && indexNs > 0) ? indexNs / cellsPerRev : c2raw[c2raw.Count / 2] / 2.0;
        // 2) classement de chaque intervalle par son nombre de cellules (arrondi), relatif a la cellule mesuree.
        //    2, 3, 4 cellules = MFM standard ; 5 cellules = marqueur de format (long tracks, syncs speciaux) : pas une erreur.
        //    cls[i] : 2, 3, 4 (MFM), 5 (marqueur tolere), 0 (hors classe ou trou).
        var c2 = new List<double>(); var c3 = new List<double>(); var c4 = new List<double>();
        int n = flux.Length; int[] cls = new int[n];
        int ooc = 0, drop = 0;
        for (int i = 0; i < n; i++) {
            int f = flux[i]; cls[i] = 0;
            if (f >= 20000) { drop++; continue; }
            double q = f / cell; int k = (int)Math.Round(q);
            if (Math.Abs(q - k) > 0.35) { ooc++; continue; }        // trop loin d un multiple entier : erreur
            if (k == 2) { c2.Add(f); cls[i] = 2; } else if (k == 3) { c3.Add(f); cls[i] = 3; } else if (k == 4) { c4.Add(f); cls[i] = 4; }
            else if (k == 5) { cls[i] = 5; /* marqueur, tolere */ } else ooc++;
        }
        r.OutOfClass = ooc; r.Dropouts = drop;
        if (c2.Count < 50) { r.Cell = cell; r.Jitter = double.NaN; r.R3 = double.NaN; r.R4 = double.NaN; return r; }
        r.Cell = cell;
        double m2 = 0; foreach (double v in c2) m2 += v; m2 /= c2.Count;
        double sq = 0; foreach (double v in c2) sq += (v - m2) * (v - m2); r.Jitter = Math.Sqrt(sq / c2.Count);
        double m3 = 0; foreach (double v in c3) m3 += v; m3 = c3.Count > 0 ? m3 / c3.Count : double.NaN;
        double m4 = 0; foreach (double v in c4) m4 += v; m4 = c4.Count > 0 ? m4 / c4.Count : double.NaN;
        r.R3 = m3 / m2; r.R4 = m4 / m2;
        // 3) decalage de pic residuel (ce que corrige la precompensation) : a la lecture, une transition
        //    est repoussee par sa voisine la plus proche. Un 2T encadre par deux intervalles longs (3T/4T)
        //    est donc lu plus long qu un 2T encadre par deux 2T ; un 3T encadre par deux 2T est lu plus
        //    court qu un 3T encadre par deux longs. Shift = demi-somme des deux ecarts (ns) : > 0 sous-
        //    compense, < 0 sur-compense, 0 = reglage ideal. Lineaire en la precomp ecrite.
        //    Les quatre contextes doivent compter au moins 30 occurrences : un estimateur a un seul contexte est
        //    biaise (simulations : de -55 a +27 ns). Erreur-type = demi-racine de la somme des variances des moyennes.
        double sSL = 0, sSS = 0, sLS = 0, sLL = 0, qSL = 0, qSS = 0, qLS = 0, qLL = 0; int nSL = 0, nSS = 0, nLS = 0, nLL = 0;
        for (int i = 1; i < n - 1; i++) {
            int k = cls[i]; if (k != 2 && k != 3) continue;
            int a = cls[i - 1], b = cls[i + 1];
            if (a < 2 || a > 4 || b < 2 || b > 4) continue;
            bool aL = a >= 3, bL = b >= 3; double f = flux[i];
            if (k == 2) { if (aL && bL) { sSL += f; qSL += f * f; nSL++; } else if (!aL && !bL) { sSS += f; qSS += f * f; nSS++; } }
            else        { if (!aL && !bL) { sLS += f; qLS += f * f; nLS++; } else if (aL && bL) { sLL += f; qLL += f * f; nLL++; } }
        }
        r.NSL = nSL; r.NSS = nSS; r.NLS = nLS; r.NLL = nLL;
        r.ShiftN = Math.Min(Math.Min(nSL, nSS), Math.Min(nLS, nLL));
        if (r.ShiftN >= 30) {
            double mSL = sSL / nSL, mSS = sSS / nSS, mLS = sLS / nLS, mLL = sLL / nLL;
            r.Shift = ((mSL - mSS) - (mLS - mLL)) / 2;
            double v = Math.Max(0, qSL / nSL - mSL * mSL) / nSL + Math.Max(0, qSS / nSS - mSS * mSS) / nSS
                     + Math.Max(0, qLS / nLS - mLS * mLS) / nLS + Math.Max(0, qLL / nLL - mLL * mLL) / nLL;
            r.ShiftSE = Math.Sqrt(v) / 2;
        }
        return r;
    }
    // --- Pistes non reproductibles et empreinte -------------------------------------------------------------------
    // Classes des intervalles d un tour : '2' a '5' (nombre de cellules), 'x' hors classe ou trou.
    public static string Classes(int[] flux, double cell) {
        var sb = new System.Text.StringBuilder(flux.Length);
        foreach (int f in flux) {
            if (f >= 20000 || cell <= 0) { sb.Append('x'); continue; }
            double q = f / cell; int k = (int)Math.Round(q);
            sb.Append((Math.Abs(q - k) > 0.35 || k < 2 || k > 5) ? 'x' : (char)('0' + k));
        }
        return sb.ToString();
    }
    // Bloc « riche » : aucune classe au-dessus de maxShare du bloc, aucun intervalle hors classe (pas un gap ni un sync)
    static bool Rich(string s, int start, int len, double maxShare) {
        int[] c = new int[128]; int mx = 0;
        for (int i = start; i < start + len; i++) { int k = s[i] & 127; c[k]++; if (c[k] > mx) mx = c[k]; }
        return c['x'] == 0 && mx <= maxShare * len;
    }
    // Stabilite d une piste d un tour a l autre : le premier tour est decoupe en blocs de 64 intervalles, chacun cherche
    // dans les autres tours pres de sa position attendue (decalage suivi, fenetre de +/- 600 intervalles). Un bloc
    // introuvable dans un autre tour est instable. Premier et dernier blocs ignores (bord du tour, index). Une suite de
    // plusieurs blocs instables = bits faibles (protection) ou defaut localise ; un bloc isole = raccord d ecriture.
    // Renvoie { blocs, blocs instables, plus longue suite instable, debut de cette suite en pour mille }.
    public static int[] Instability(List<int[]> revs, double cell) {
        // Deux tours de reference (0 puis 1) : une erreur de lecture du tour de reference rendrait le bloc introuvable
        // partout ailleurs ; on garde le resultat le moins instable. Avec deux tours, une erreur isolee n est pas
        // distinguable d un bit faible.
        var res = new int[] { 0, 0, 0, -1 };
        if (revs == null || revs.Count < 2 || double.IsNaN(cell) || cell <= 0) return res;
        var cls = new List<string>(); foreach (var r in revs) cls.Add(Classes(r, cell));
        int[] a0 = InstabilityRef(cls, 0);
        if (cls.Count < 3) return a0;
        int[] a1 = InstabilityRef(cls, 1);
        return (a1[2] < a0[2] || (a1[2] == a0[2] && a1[1] < a0[1])) ? a1 : a0;
    }
    // Tour de reference decoupe en blocs de 32 intervalles, chacun cherche dans les autres tours pres de sa position
    // attendue (decalage suivi, fenetre de +/- 600 intervalles). Un bloc est instable s il manque dans au moins deux
    // autres tours (une erreur aleatoire ne touche qu un tour ; des bits faibles changent a chaque tour). Premier et
    // dernier blocs ignores (bord du tour, index). Une suite de blocs instables = bits faibles ou defaut localise ; un
    // raccord d ecriture est un defaut physique fixe, relu pareil a chaque tour.
    static int[] InstabilityRef(List<string> cls, int refIdx) {
        const int L = 32, W = 600;
        var res = new int[] { 0, 0, 0, -1 };
        string a = cls[refIdx];
        int nb = a.Length / L; if (nb < 8) return res;
        int[] miss = new int[nb];
        for (int r = 0; r < cls.Count; r++) {
            if (r == refIdx) continue;
            string b = cls[r]; int off = 0;
            for (int i = 1; i < nb - 1; i++) {
                int exp = i * L + off;
                // bloc a sa place attendue : cas le plus frequent, sans recherche
                if (exp >= 0 && exp + L <= b.Length && string.CompareOrdinal(a, i * L, b, exp, L) == 0) continue;
                string blk = a.Substring(i * L, L);
                int s = Math.Max(0, exp - W), e = Math.Min(b.Length, exp + L + W);
                if (e - s < L) { miss[i]++; continue; }
                if (!Rich(a, i * L, L, 0.8)) {
                    if (b.IndexOf(blk, s, e - s, StringComparison.Ordinal) < 0) miss[i]++;
                    continue;
                }
                int best = -1, bestD = int.MaxValue, p = s;
                while (p <= e - L) {
                    int q = b.IndexOf(blk, p, e - p, StringComparison.Ordinal);
                    if (q < 0) break;
                    int d = Math.Abs(q - exp); if (d < bestD) { bestD = d; best = q; }
                    p = q + 1;
                }
                if (best >= 0) off = best - i * L; else miss[i]++;
            }
        }
        int need = Math.Min(2, cls.Count - 1);
        int nbad = 0, run = 0, top = 0, topStart = -1, start = 0;
        for (int i = 0; i < nb; i++) {
            if (miss[i] >= need) { nbad++; if (run == 0) start = i; run++; if (run > top) { top = run; topStart = start; } }
            else run = 0;
        }
        res[0] = nb; res[1] = nbad; res[2] = top; res[3] = topStart < 0 ? -1 : (int)(1000L * topStart / nb);
        return res;
    }
    // Blocs riches presents une seule fois dans le tour : exclut les remplissages periodiques (E5E5 Atari, 4E...) et
    // les en-tetes communs a toute disquette du meme format
    static List<int> Qualified(string a) {
        const int L = 64; var q = new List<int>(); int nb = a.Length / L;
        for (int i = 1; i < nb - 1; i++) {
            if (!Rich(a, i * L, L, 0.6)) continue;
            string blk = a.Substring(i * L, L);
            if (a.IndexOf(blk, StringComparison.Ordinal) != a.LastIndexOf(blk, StringComparison.Ordinal)) continue;
            q.Add(i);
        }
        return q;
    }
    // Empreinte d une piste : jusqu a n blocs qualifies de 64 intervalles du premier tour, repartis sur la piste ;
    // aucune si la piste a moins de 24 blocs qualifies (piste vide ou formatee sans donnees propres : E5E5, 4E...)
    public static string[] Fingerprint(int[] flux, double cell, int n) {
        var outp = new List<string>();
        if (flux == null || double.IsNaN(cell) || cell <= 0) return outp.ToArray();
        string a = Classes(flux, cell); var q = Qualified(a);
        if (q.Count < 24) return outp.ToArray();
        int k = Math.Min(n, q.Count);
        for (int j = 0; j < k; j++) { int i = q[(int)((long)j * q.Count / k)]; outp.Add(a.Substring(i * 64, 64)); }
        return outp.ToArray();
    }
    public static int RichCount(int[] flux, double cell) {
        if (flux == null || double.IsNaN(cell) || cell <= 0) return 0;
        return Qualified(Classes(flux, cell)).Count;
    }
    // Nombre de blocs de l empreinte retrouves dans les tours d une autre lecture. Chaque tour est classe avec la cellule
    // de l original ET avec sa propre cellule : un lecteur de destination d une autre vitesse decale toutes les classes.
    public static int Match(List<int[]> revs, double cell, string[] fp) {
        if (revs == null || fp == null || fp.Length == 0) return 0;
        var sb = new System.Text.StringBuilder();
        foreach (var r in revs) {
            if (r == null) continue;
            if (!double.IsNaN(cell) && cell > 0) { sb.Append(Classes(r, cell)); sb.Append('|'); }
            double c = Analyze(r, 0).Cell;
            if (!double.IsNaN(c) && c > 0) { sb.Append(Classes(r, c)); sb.Append('|'); }
        }
        string s = sb.ToString(); int n = 0;
        foreach (var f in fp) if (s.IndexOf(f, StringComparison.Ordinal) >= 0) n++;
        return n;
    }
    public static int[] Decode(byte[] data, int offset, int count, int resNs) {
        var outp = new List<int>(count); long carry = 0;
        for (int i = 0; i < count; i++) {
            int v = (data[offset + 2 * i] << 8) | data[offset + 2 * i + 1];
            if (v == 0) { carry += 65536; continue; }
            outp.Add((int)((v + carry) * resNs)); carry = 0;
        }
        return outp.ToArray();
    }
}
public static class CalibPattern {
    // Motif de test de la calibration precomp : image HFE v1 telle que gw la lit (image/hfe.py). En-tete de 512 octets
    // (debit en kbit/s a l offset 12), table des pistes au bloc 1 (decalage en blocs de 512 octets, longueur des deux
    // faces en octets), donnees des le bloc 2 en blocs de 256 octets alternes face 0 / face 1, premiere cellule dans le
    // bit de poids faible. Chaque piste : un tour a 300 tr/min (2000 x debit cellules par seconde) de donnees
    // pseudo-aleatoires codees MFM, sans structure de secteur : meme statistique de motifs sur toutes les pistes.
    public static void WriteHfe(string path, int nCyl, int nBits, int rate, int seed) {
        // nBits : cellules par piste (multiple de 16). gw cale chaque piste ecrite sur un tour du lecteur : c est ce nombre,
        // et non le debit de l en-tete, qui fixe la densite ecrite. Longueur des deux faces sur 16 bits dans la table.
        if (nCyl < 1 || nCyl > 255 || nBits < 16 || nBits % 16 != 0 || nBits / 4 > 0xFFFF || rate < 1 || rate > 0xFFFF)
            throw new ArgumentOutOfRangeException("nBits", "HFE : " + nCyl + " cylindres, " + nBits + " cellules par piste hors limites");
        int nBytes = nBits / 8, nBlocks = (nBytes + 255) / 256;
        byte[] head = new byte[512]; for (int i = 0; i < 512; i++) head[i] = 0xFF;
        Array.Copy(System.Text.Encoding.ASCII.GetBytes("HXCPICFE"), head, 8);
        head[8] = 0; head[9] = (byte)nCyl; head[10] = 2; head[11] = 0xFF;   // revision, cylindres, faces, codage inconnu
        head[12] = (byte)(rate & 0xFF); head[13] = (byte)(rate >> 8);       // debit (kbit/s)
        head[14] = 0; head[15] = 0; head[16] = 0xFF; head[17] = 1;          // tr/min inutilise, interface inconnue, reserve
        head[18] = 1; head[19] = 0; head[20] = 0xFF; head[21] = 0xFF;       // table au bloc 1, ecriture permise, pas simple
        byte[] tlut = new byte[512]; for (int i = 0; i < 512; i++) tlut[i] = 0xFF;
        for (int c = 0; c < nCyl; c++) {
            int off = 2 + c * nBlocks, len = 2 * nBytes;
            tlut[c * 4] = (byte)(off & 0xFF); tlut[c * 4 + 1] = (byte)(off >> 8);
            tlut[c * 4 + 2] = (byte)(len & 0xFF); tlut[c * 4 + 3] = (byte)(len >> 8);
        }
        var rnd = new Random(seed);
        using (var fs = new System.IO.FileStream(path, System.IO.FileMode.Create, System.IO.FileAccess.Write)) {
            fs.Write(head, 0, 512); fs.Write(tlut, 0, 512);
            byte[] blk = new byte[256];
            for (int c = 0; c < nCyl; c++) {
                byte[][] side = new byte[][] { Track(rnd, nBits), Track(rnd, nBits) };
                for (int b = 0; b < nBlocks; b++)
                    for (int s = 0; s < 2; s++) {
                        for (int i = 0; i < 256; i++) { int k = b * 256 + i; blk[i] = k < nBytes ? side[s][k] : (byte)0x88; }
                        fs.Write(blk, 0, 256);
                    }
            }
        }
    }
    static byte[] Track(Random rnd, int nBits) {
        // MFM : une cellule d horloge puis une de donnee par bit ; horloge a 1 seulement entre deux bits de donnee a 0
        byte[] t = new byte[nBits / 8]; int prev = 0;
        for (int i = 0; i < nBits; i += 2) {
            int d = rnd.Next(2), clk = (prev == 0 && d == 0) ? 1 : 0;
            if (clk == 1) t[i >> 3] |= (byte)(1 << (i & 7));
            if (d == 1) t[(i + 1) >> 3] |= (byte)(1 << ((i + 1) & 7));
            prev = d;
        }
        return t;
    }
}
'@ -ErrorAction Stop
    $script:ScpStatsOk = $true
} catch { }

# Ajustement de la courbe de calibration monotone par segments : bloc separe (un echec de compilation garde
# l ajustement croissant d origine sans toucher a l analyse de flux)
$script:CurveFitOk = $false
try {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
public static class CurveFit {
    // PAVA pondere sur y[from..to), croissant (inc) ou decroissant
    static double[] Pava(double[] y, double[] w, int from, int to, bool inc) {
        var v = new List<double>(); var wt = new List<double>(); var cnt = new List<int>();
        for (int i = from; i < to; i++) {
            v.Add(inc ? y[i] : -y[i]); wt.Add(w[i]); cnt.Add(1);
            while (v.Count >= 2 && v[v.Count - 2] > v[v.Count - 1]) {
                int a = v.Count - 2, b = v.Count - 1;
                double ww = wt[a] + wt[b];
                v[a] = ww > 0 ? (v[a] * wt[a] + v[b] * wt[b]) / ww : (v[a] + v[b]) / 2; wt[a] = ww; cnt[a] += cnt[b];
                v.RemoveAt(b); wt.RemoveAt(b); cnt.RemoveAt(b);
            }
        }
        var o = new double[to - from]; int k = 0;
        for (int j = 0; j < v.Count; j++) for (int c = 0; c < cnt[j]; c++) o[k++] = inc ? v[j] : -v[j];
        return o;
    }
    static double Cost(double[] y, double[] w, double[] f, int from) {
        double s = 0; for (int i = 0; i < f.Length; i++) { double e = y[from + i] - f[i]; s += w[from + i] * e * e; } return s;
    }
    static double[] Join(double[] a, double[] b, double[] d) {
        int n = a.Length + b.Length + (d == null ? 0 : d.Length); var o = new double[n]; int k = 0;
        foreach (double x in a) o[k++] = x; foreach (double x in b) o[k++] = x;
        if (d != null) foreach (double x in d) o[k++] = x;
        return o;
    }
    // Monotone par segments : K = 0 (croissant), 1 (croissant puis decroissant) ou 2 (croissant, decroissant, croissant).
    // Cout = somme ponderee des ecarts au carre + K x pen ; un changement de sens n est admis que sur une chute nette
    // (sommet - creux > minDrop) entre deux points fiables (encadres). Renvoie { K, t1, t2, cout, f0 ... fn-1 } :
    // segments [0, t1), [t1, t2), [t2, n).
    public static double[] SegFit(double[] y, double[] w, bool[] reliable, double pen, double minDrop) {
        int n = y.Length;
        double[] best = Pava(y, w, 0, n, true);
        double bestCost = Cost(y, w, best, 0); int bk = 0, bt1 = n, bt2 = n;
        for (int t1 = 1; t1 < n; t1++) {
            double[] a = Pava(y, w, 0, t1, true), b = Pava(y, w, t1, n, false);
            // la montee finit sur le sommet (a[t1-1] >= b[0]) : segments sans montee cachee dans la descente
            if (b[0] > a[t1 - 1] || a[t1 - 1] - b[b.Length - 1] <= minDrop || !reliable[t1 - 1] || !reliable[n - 1]) continue;
            double c = Cost(y, w, a, 0) + Cost(y, w, b, t1) + pen;
            if (c < bestCost) { bestCost = c; bk = 1; bt1 = t1; bt2 = n; best = Join(a, b, null); }
        }
        for (int t1 = 1; t1 < n - 1; t1++) {
            double[] a = Pava(y, w, 0, t1, true);
            if (!reliable[t1 - 1]) continue;
            double ca = Cost(y, w, a, 0);
            for (int t2 = t1 + 1; t2 < n; t2++) {
                double[] b = Pava(y, w, t1, t2, false);
                if (b[0] > a[t1 - 1] || a[t1 - 1] - b[b.Length - 1] <= minDrop || !reliable[t2 - 1]) continue;
                double[] d = Pava(y, w, t2, n, true);
                if (d[0] < b[b.Length - 1]) continue;            // la descente finit sur le creux
                double c = ca + Cost(y, w, b, t1) + Cost(y, w, d, t2) + 2 * pen;
                if (c < bestCost) { bestCost = c; bk = 2; bt1 = t1; bt2 = t2; best = Join(a, b, d); }
            }
        }
        var res = new double[4 + n]; res[0] = bk; res[1] = bt1; res[2] = bt2; res[3] = bestCost;
        for (int i = 0; i < n; i++) res[4 + i] = best[i];
        return res;
    }
}
'@ -ErrorAction Stop
    $script:CurveFitOk = $true
} catch { }

# Index de bibliotheque : parcours rapide dans un thread .NET (pas de PowerShell en arriere-plan),
# recherche en memoire instantanee, persistance dans un fichier TSV local.
$script:FastIndexOk = $false
try {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Collections.Generic;
public class IdxEntry { public string Rel; public long Size; public string Kind; }
public static class FastIndex {
    static readonly object sync = new object();
    static List<IdxEntry> entries = new List<IdxEntry>();
    static HashSet<string> imgExt = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    static HashSet<string> docExt = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    public static volatile bool Busy;
    public static volatile int Scanned;
    public static string Error;
    public static string Root = "";
    public static DateTime Built = DateTime.MinValue;
    public static double LastBuildSeconds;
    public static int LastTotal;
    public static void SetExt(string[] img, string[] doc) {
        imgExt = new HashSet<string>(img, StringComparer.OrdinalIgnoreCase);
        docExt = new HashSet<string>(doc, StringComparer.OrdinalIgnoreCase);
    }
    public static string KindOf(string name) {
        string e = Path.GetExtension(name);
        if (string.Equals(e, ".zip", StringComparison.OrdinalIgnoreCase)) return "zip";
        if (imgExt.Contains(e)) return "image";
        if (docExt.Contains(e)) return "doc";
        return "other";
    }
    public static int Count { get { lock (sync) { return entries.Count; } } }
    public static void StartBuild(string root, string outFile) {
        if (Busy) return;
        Busy = true; Scanned = 0; Error = null;
        Thread t = new Thread(delegate() {
            DateTime t0 = DateTime.Now;
            List<IdxEntry> list = new List<IdxEntry>();
            try {
                string r = root.TrimEnd('\\');
                int rootLen = r.Length + 1;
                Stack<DirectoryInfo> stack = new Stack<DirectoryInfo>();
                stack.Push(new DirectoryInfo(r));
                while (stack.Count > 0) {
                    DirectoryInfo d = stack.Pop();
                    try {
                        foreach (FileSystemInfo fsi in d.EnumerateFileSystemInfos()) {
                            if ((fsi.Attributes & FileAttributes.Directory) != 0) {
                                if ((fsi.Attributes & FileAttributes.ReparsePoint) == 0) stack.Push((DirectoryInfo)fsi);
                            } else {
                                FileInfo fi = (FileInfo)fsi;
                                string full = fi.FullName;
                                IdxEntry en = new IdxEntry();
                                en.Rel = full.Length > rootLen ? full.Substring(rootLen) : fi.Name;
                                en.Size = fi.Length; en.Kind = KindOf(fi.Name);
                                list.Add(en);
                                Scanned = list.Count;
                            }
                        }
                    } catch (Exception) { }
                }
                list.Sort(delegate(IdxEntry a, IdxEntry b) { return string.Compare(a.Rel, b.Rel, StringComparison.OrdinalIgnoreCase); });
                lock (sync) { entries = list; Root = r; Built = DateTime.Now; }
                LastBuildSeconds = (DateTime.Now - t0).TotalSeconds;
                Save(outFile);
            } catch (Exception ex) { Error = ex.Message; }
            finally { Busy = false; }
        });
        t.IsBackground = true;
        t.Start();
    }
    public static void Save(string file) {
        string dir = Path.GetDirectoryName(file);
        if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
        using (StreamWriter w = new StreamWriter(file, false, new UTF8Encoding(false))) {
            lock (sync) {
                w.WriteLine("#GWIDX1\t" + Root + "\t" + Built.Ticks.ToString());
                foreach (IdxEntry e in entries) w.WriteLine(e.Rel + "\t" + e.Size.ToString() + "\t" + e.Kind);
            }
        }
    }
    public static bool Load(string file, string root) {
        if (!File.Exists(file)) return false;
        List<IdxEntry> list = new List<IdxEntry>();
        string r = root.TrimEnd('\\'); DateTime built = File.GetLastWriteTime(file);
        using (StreamReader rd = new StreamReader(file, Encoding.UTF8)) {
            string line = rd.ReadLine();
            if (line == null || !line.StartsWith("#GWIDX1")) return false;
            string[] h = line.Split('\t');
            if (h.Length >= 3) { long ticks; if (long.TryParse(h[2], out ticks)) built = new DateTime(ticks); }
            while ((line = rd.ReadLine()) != null) {
                string[] p = line.Split('\t');
                if (p.Length < 3) continue;
                IdxEntry e = new IdxEntry(); e.Rel = p[0]; long sz; long.TryParse(p[1], out sz); e.Size = sz; e.Kind = p[2];
                list.Add(e);
            }
        }
        lock (sync) { entries = list; Root = r; Built = built; }
        return true;
    }
    public static IdxEntry[] Search(string query, bool imgOnly, int max) {
        string[] words = query.Split(new char[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
        List<IdxEntry> res = new List<IdxEntry>(); int total = 0;
        lock (sync) {
            foreach (IdxEntry e in entries) {
                if (imgOnly && e.Kind != "image" && e.Kind != "zip") continue;
                bool ok = true;
                foreach (string w in words) { if (e.Rel.IndexOf(w, StringComparison.OrdinalIgnoreCase) < 0) { ok = false; break; } }
                if (!ok) continue;
                total++;
                if (res.Count < max) res.Add(e);
            }
        }
        LastTotal = total;
        return res.ToArray();
    }
}
'@ -ErrorAction Stop
    [FastIndex]::SetExt([string[]]$script:ImgExt, [string[]]$script:DocExt)
    $script:FastIndexOk = $true
} catch { }
