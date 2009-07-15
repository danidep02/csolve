/* Generated by CIL v. 1.3.7 */
/* print_CIL_Input is true */

extern char *malloc(int);
extern int nondet();
extern int nondetnn();
extern void exit(int);

struct node_t {
   int value ;
   struct node_t *next ;
   int from_count ;
   struct node_t **to_nodes ;
   struct node_t **from_nodes ;
   int *coeffs ;
};
typedef struct node_t node_t;
struct graph_t {
   node_t *e_nodes ;
   node_t *h_nodes ;
};
typedef struct graph_t graph_t;
void compute_nodes(node_t *nodelist ) ;
graph_t initialize_graph(void) ;

int gen_number(int range )
{ long tmp ;

    int ndnn = nondetnn();

    if (ndnn < range)
        return ndnn;

    return 0;
}

node_t **make_table(int size )
{ node_t **retval ;
  void *tmp ;

  {
  tmp = malloc((unsigned int )size * sizeof(node_t *));
  retval = (node_t **)tmp;
  if (retval == 0) {
      // printf((char const   * __restrict  )"Assertion failure\n");
    exit(-1);
  }

  return (retval);
}
}

void fill_table(node_t **table , int size )
{ int i ;
  void *tmp ;
  int tmp___0 ;

  {
  i = 0;
  while (i < size) {
    tmp = malloc(sizeof(node_t ));
    *(table + i) = (node_t *)tmp;
    tmp___0 = nondet();
    (*(table + i))->value = (int )tmp___0;
    (*(table + i))->from_count = 0;
    if (i > 0) {
      (*(table + (i - 1)))->next = *(table + i);
    }
    i ++;
  }
  (*(table + (size - 1)))->next = (struct node_t *)((void *)0);
  return;
}
}

void fill_from_fields(node_t *nodelist , int degree )
{ node_t *cur_node ;
  int j ;
  node_t *other_node ;

  {
  cur_node = nodelist;
  while (cur_node) {
    j = 0;
    while (j < degree) {
      other_node = *(cur_node->to_nodes + j);
      *(other_node->from_nodes + other_node->from_count) = cur_node;
      (other_node->from_count) ++;
      j ++;
    }
    cur_node = cur_node->next;
  }
  return;
}
}

void make_neighbors(node_t *nodelist , int tablesz , node_t **table , int degree )
{ node_t *cur_node ;
  node_t *other_node ;
  int j ;
  int k ;
  void *tmp ;
  int tmp___0 ;

  {
  cur_node = nodelist;
  while (cur_node) {
    tmp = malloc((unsigned int )degree * sizeof(node_t *));
    cur_node->to_nodes = (node_t **)tmp;
    j = 0;
    while (j < degree) {
      while (1) {
        tmp___0 = gen_number(tablesz);
        other_node = *(table + tmp___0);
        k = 0;
        while (k < j) {
          if ((unsigned int )other_node == (unsigned int )*(cur_node->to_nodes + k)) {
            break;
          }
          k ++;
        }
        if ((k >= j)) {
          break;
        }
      }
      *(cur_node->to_nodes + j) = other_node;
      (other_node->from_count) ++;
      j ++;
    }
    cur_node = cur_node->next;
  }
  return;
}
}

/*
int main(int argc , char **argv )
{ int i ;
  graph_t graph ;

  {
  graph = initialize_graph();
  // print_graph(graph);
  i = 0;
  while (i < 100) {
    compute_nodes(graph.e_nodes);
    compute_nodes(graph.h_nodes);
    // fprintf((FILE * __restrict  )stderr, (char const   * __restrict  )"Completed a computation phase: %d\n",
    //        i);
    // print_graph(graph);
    i ++;
  }
  return (0);
}
}
void compute_nodes(node_t *nodelist )
{ int i ;
  node_t *other_node ;
  int coeff ;
  int value ;

  {
  while (nodelist) {
    i = 0;
    while (i < nodelist->from_count) {
      other_node = *(nodelist->from_nodes + i);
      coeff = *(nodelist->coeffs + i);
      value = other_node->value;
      nodelist->value = (int )(nodelist->value - coeff * value);
      i ++;
    }
    nodelist = nodelist->next;
  }
  return;
}
}
void update_from_coeffs(node_t *nodelist )
{ node_t *cur_node ;
  int from_count ;
  int k ;
  void *tmp ;
  void *tmp___0 ;
  int tmp___1 ;

  {
  cur_node = nodelist;
  while (cur_node) {
    from_count = cur_node->from_count;
    tmp = malloc((unsigned int )from_count * sizeof(node_t *));
    cur_node->from_nodes = (node_t **)tmp;
    tmp___0 = malloc((unsigned int )from_count * sizeof(int ));
    cur_node->coeffs = (int *)tmp___0;
    k = 0;
    while (k < from_count) {
        tmp___1 = nondet();
      *(cur_node->coeffs + k) = (int )tmp___1;
      k ++;
    }
    cur_node->from_count = 0;
    cur_node = cur_node->next;
  }
  return;
}
}
graph_t initialize_graph(void)
{ int num_h_nodes ;
  int num_e_nodes ;
  node_t **h_table ;
  node_t **e_table ;
  graph_t retval ;

  {
  num_h_nodes = 666;
  num_e_nodes = 666;
  h_table = make_table(num_h_nodes);
  fill_table(h_table, 666);
  e_table = make_table(num_e_nodes);
  fill_table(e_table, 666);
  make_neighbors(*(h_table + 0), 666, e_table, 333);
  make_neighbors(*(e_table + 0), 666, h_table, 333);
  update_from_coeffs(*(h_table + 0));
  update_from_coeffs(*(e_table + 0));
  fill_from_fields(*(h_table + 0), 333);
  fill_from_fields(*(e_table + 0), 333);
  retval.e_nodes = *(e_table + 0);
  retval.h_nodes = *(h_table + 0);
  return (retval);
}
}
*/
