//! run with --manual

#include <stdlib.h>

struct hash {
   int* ARRAY array ;
   int size ;
};

typedef struct hash *Hash;

Hash main(){
  int size;
  size = nondetpos();
  Hash retval ;
  retval = (struct hash *) malloc((int )sizeof(*retval));
  retval->size = size;
  retval->array = (int *) malloc((int )(size * sizeof(*(retval->array + 0))));
  
  for (int i=0; i < size; i++){
    retval->array[i] = 0;
  }
  //NUKE memset((char *)retval->array, 0, (unsigned int )size * sizeof(*(retval->array + 0)));
    return retval;
}
