#include <liquidc.h>

int two () {
    return 2;
}

int main () {
    int (*f) () = &two;
    int x = f ();
    csolve_assert (x > 0);

    return 0;
}
