int (*f) ();

int one () {
    return 0;
}

int main () {
    f = &one;
    lcc_assert (f () > 0);

    return 0;
}
