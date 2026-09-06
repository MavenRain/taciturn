pragma circom 2.1.0;

// spike/circom/mimc3.circom
// MiMC-3 per stage-0-brief.md section 4: field BN254 scalar, round constants
// c = [1, 2, 3], seventh-power S-box through four quadratic constraints per
// round (t2, t4, t6, xnext), public input k, public output h, private input x.
// These constants are spike constants for a three-agent format cross-check;
// they are not the MiMC-7 constants of circomlib and carry no security claim.

template MiMC3() {
    signal input x;
    signal input k;
    signal output h;

    var c[3] = [1, 2, 3];

    signal xs[4];
    xs[0] <== x;

    signal t[3];
    signal t2[3];
    signal t4[3];
    signal t6[3];

    for (var i = 0; i < 3; i++) {
        t[i] <== xs[i] + k + c[i];
        t2[i] <== t[i] * t[i];
        t4[i] <== t2[i] * t2[i];
        t6[i] <== t4[i] * t2[i];
        xs[i + 1] <== t6[i] * t[i];
    }

    h <== xs[3] + k;
}

component main {public [k]} = MiMC3();
