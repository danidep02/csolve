#include <stdlib.h>

typedef struct node {
  int data;
  struct node *next;
} node_t;

int foo(int n){
  node_t *root;
  node_t *tmp;
  int i;

  root = 0;
  
//  lcc_assert(0); //SANITY

  for(i = 0; i < n; i++){
    tmp       = (node_t *) malloc(sizeof(node_t));
    tmp->data = i;
    tmp->next = root;
    root      = tmp;
  }

//  lcc_assert(0); //SANITY

  for(tmp = root; tmp != (node_t*) 0; tmp = tmp->next){
    lcc_assert(tmp->data >= 0);
    lcc_assert(tmp->data < n);
    lcc_assert(tmp->data < 100);
//    lcc_assert(0); //SANITY
  }

return 0;
}

int main(){
  foo(100);
  return 0;
}
