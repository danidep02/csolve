#include <cpj.h>
#include <stdlib.h>
#include <math.h>

const int REF (V > 0) buf_len; 
const int REF (V > 0) merge_size;

//define buf_len 10000
//define merge_size 50

int main() //int argc, char **argv)
{
  int len = buf_len;  

  int * in  = malloc(sizeof(int) * len);
  int * out = malloc(sizeof(int) * len);

  initialize(in, len);
  initialize(out, len);

  //mergesort(in, 0, len, out);
  mergesort(in, out, len);  // RJ: CHECK THIS
  
  check_sorted(in, len);
  
  return 0;
}

void initialize(int * ARRAY START buf, int len)
{
  foreach(i, 0, len)
    buf[i] = nondet();
  endfor
}

//a: ptr(l1, i1) / l1 => (0+: int)  -> b: ptr(l2, i2) / l2 => (0+: int)
//                                  -> len: int
//                                  -> () / h: l1 => (0+: int), l2 => (0+: int);
//                                          r: l1 => (i1 <= v < i1 + len), l2 => (i2 <= v < i2 + len);
//                                          w: l1 => (i1 <= v < i1 + len), l2 => (i2 <= v < i2 + len) 
void mergesort(int * ARRAY a, int * ARRAY b, int len) {
  int q  = len / 4;
  int h  = 2*q;
  int r  = len - 3*q;
   
  cobegin
    rtn(mergesort(a      , b    , q))
    rtn(mergesort(a + q  , b + q, q))
    rtn(mergesort(a + h  , b + h, q))
    //rtn(mergesort(a + 3*q, len, r)) //RJ: WTF? Where is the "b" argument?
  coend 

  cobegin
    rtn(merge(a, a + q, q, q, b))
    rtn(merge(a + h, a + 3*q, q, r, b + h))
  coend 

  merge(b, b + h, h, len - h, a);
}

void seq_merge(int * ARRAY LOC(Li) a, int * ARRAY LOC(Li) b, int lena, int lenb, int * ARRAY LOC(Lo) c) 
{
  int i, j, k;
  i = j = k = 0;

  while (i < lena && j < lenb)
    if (a[i] < b[j])   
      c[k++] = a[i++];
    else
      c[k++] = b[j++];

  while (i < lena) c[k++] = a[i++];
  while (j < lenb) c[k++] = b[i++];
}

//a: ptr(l1, i1) / l1 => (0+: int) -> b: ptr(l2, i2) / l2 => (0+: int)
//                                 -> lena: int -> lenb: int
//                                 -> c: ptr(l3, i3) / l3 => (0+: int)
//                                 -> () / h: l1 => (0+: int), l2 => (0+: int), l3 => (0+: int);
//                                         r: l1 => (i1 <= v < i1 + lena), l2 => (i2 <= v < i2 + lenb), l3 => F
//                                         w: l1 => F, l2 => F, l3 => (i3 <= v < i3 + lena + lenb)
void merge(int * ARRAY LOC(Li) a, int * ARRAY LOC(Li) b, int lena, int lenb, int * LOC(Lo) ARRAY c)
{
  if (lena <= merge_size){ 
    seq_merge(a, b, lena, lenb, c);
  } else {
    int ha = lena / 2;
    int sb = find_split(a[ha], b, lenb);// RJ: CHECK IF THIS IS RIGHT!

    cobegin
      rtn(merge(a, b, ha, sb, c))
      rtn(merge(a + ha, b + sb, lena - ha, lenb - sb, c + ha + sb))
    coend
  }
}

int find_split(int v, int * ARRAY b, int len)
{
  int lo = 0;
  int hi = len;
  int m;

  while (lo < hi) {
    m = lo + ((hi - lo) / 2);
    if (v <= b[m]) 
      hi = m;
    else
      lo = m + 1;
  }
  return hi;
}

bool check_sorted(int * ARRAY buf, int len)
{
  int i;
  int n = nondet();
  lcc_assert (0);

  for (i = 0; i < len - 1; i++)
    if (buf[i] <= buf[n]) //i + 1])
      return FALSE;
  return TRUE;
}
