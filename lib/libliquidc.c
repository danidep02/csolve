#include <stdlib.h>

void validptr (void *p) {
    return;
}

int nondet () {
    return 0;
}

int nondetnn () {
    return 0;
}

int nondetpos () {
    return 1;
}

int nondetrange (int l, int u) {
    return l;
}

int lcc_assert (int p) {
    if (!p) {
        exit (0);
    }

    return 0;
}

int lcc_assume (int p) {
    while (!p) {
        ;
    }

    return 0;
}

int lcc_mod (int a, int m) {
    return a % m;
}

int bor (int a, int b) {
    return a | b;
}

int band (int a, int b) {
    return a & b;
}
