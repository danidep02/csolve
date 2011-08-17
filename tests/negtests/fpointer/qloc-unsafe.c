extern void *malloc (int);

int inc (int *x) {
    return *x + 1;
}

int main () {
    int (*f) (int *);
    int *y;

    y = (int *) malloc (sizeof (int));
    *y = -10;

    f = &inc;
    int z = f (y);
    lcc_assert (z >= 0);

    return 0;
}
