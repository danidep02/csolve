#include <stdlib.h>

typedef struct {
    int x;
    int y;
} str;

void test(str *s) {
    int x, y;
    
    s = s; //THETA ISSUE

    x = s->x;
    y = s->y;
    lcc_assert(y >= x);
}

void main() {
    str s;
    int x, y;

    x = nondetpos();
    y = x + 1;
    lcc_assert(y >= x);

    s.x = x;
    s.y = y;

    test(&s);
}
