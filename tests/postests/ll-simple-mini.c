#include <stdlib.h>

typedef struct node {
  int data;
  struct node *next;
} node_t;

int main(){
  node_t *root;
  node_t *tmp;

  root = 0;
  
  for(int i=0; i < 1000; i++){
    tmp       = (node_t *) malloc(sizeof(node_t));
    validptr(tmp);
    tmp->data = 10;
    tmp->next = root;
    root      = tmp;
  }

  /*for(tmp = root; tmp != (node_t*) 0; tmp = tmp->next){
      csolve_assert(tmp->data >= 0);
      csolve_assert(tmp->data < 1000);
  }*/
  return 0;
}
