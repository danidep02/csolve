extern void *malloc (int);

int main () {
    int *x = (int *) malloc (sizeof (int));
    *x = nondet ();

    int *y = (int *) malloc (sizeof (int));
    *y = nondet ();

    int **p = (int **) malloc (sizeof (int *));
    *p = x;

    int **q = (int **) malloc (sizeof (int *));
    *q = y;

    if (nondet ()) {
        p = q;
    }

    if (p == q) {
        assert (**p == **q);
    }
    
    return 0;
}