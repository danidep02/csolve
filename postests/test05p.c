extern char* malloc(int);
extern int **make_ptr();

void set_ptr(int **p, int v){
  int *x;
   x = (int *)malloc(sizeof(int));
  *x = v;
  *p = x;
  return;
}

void main(){
  int **t;
  int *t1;
  int t2;

  t = make_ptr();
  t1 = *t; 	// test minimization
  set_ptr(t, 10);
  
  validptr(t);	//should succeed

  return; 
}
