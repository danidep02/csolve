void nop () {
    return;
}

int main () {
    void (*f) ();

    if (nondet ()) {
        f = &nop;
    } else {
        f = 0;
    }

    if (f != 0)
        f ();
    
    return 0;
}
