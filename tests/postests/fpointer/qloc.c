#include <stdlib.h>
#include <liquidc.h>

int inc (int *x) {
    return *x + 1;
}

int main () {
    int (*f) (int *);
    int *y;

    y = (int *) malloc (sizeof (int));
    *y = 3;

    f = &inc;
    int z = f (y);
    assert (z >= 0);

    return 0;
}
