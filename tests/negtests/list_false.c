#include <stdlib.h>

typedef struct _node {
    struct _node *next;
} node;

void insert (node * LOC(L) * LOC(L) hd, node * LOC(L) v) {
    node **_e_;

    /* assert (0); */
    _e_  = hd;
    *_e_ = v;

    assert (0);
}

int main () {
    node hd;

    insert (&hd, &hd);

    return 0;
}
