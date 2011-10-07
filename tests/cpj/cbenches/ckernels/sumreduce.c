
int main(char ** args, int vargs)
{
  if (vargs != 3)
    return 1;
  int seqLen = atoi(args[0]);

  int * arr;
  int len;

  arr = malloc(sizeof(int) * len);

  initialize(arr, len);
  reduce(arr, len);
}

//a: ptr(l, i) -> len: int -> () / h: l => (0+: int);
//                                 r: l => F;
//                                 w: l => i <= v < i + len;
void initialize(int  * a, int len) {
  int i;
  foreach(i in 0 to len) {
    a[i] = i;
  }
}

//a: ptr(l, i) -> len: int -> seqLen: int -> int / h: l => (0+: int);
//                                                 r: l => i <= v < i + len;
//                                                 w: l => F
int reduce(int * a, int len, int seqLen)
{ 
  int i = 0;

  if (len == 0) return 0;
  if (len == 1) return a[0];
  int result = 0;
  if (len > seqLen) {
    int tmp1, tmp2, h = len/2;
    cobegin {
      tmp1 = reduce(a, h, seqLen)
      tmp2 = reduce(a + h, h, seqLen)
    }
    result = tmp1 + tmp2;
    } else
      for (i = 0; i < len; i++)
        result = result + a[i];
    return result;
}
