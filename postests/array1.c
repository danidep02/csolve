extern char* malloc(int);

int main(){
  int *x;
  
  x = (int *) malloc(100);
  
  while(nondet()){
/*     validptr(x); */
    *x = 0;
 //   x++;
  }
  
  return 0;
}
