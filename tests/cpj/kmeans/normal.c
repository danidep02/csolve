/* =============================================================================
 *
 * normal.c
 * -- Adapted from the Stanford STAMP project
 * -- Implementation of normal k-means clustering algorithm
 *
 * =============================================================================
 */

#define __MAKE_SEQ

#include <cpj.h>

//#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <float.h>
#include <math.h>
#include "common.h"
#include "normal.h"
#include "util.h"

double global_time = 0.0;

typedef struct args {
    float * ARRAY * ARRAY feature;
    int                   nfeatures;
    int                   npoints;
    int                   nclusters;
    int * ARRAY           membership;
    float * ARRAY * ARRAY clusters;
    int** ARRAY           new_centers_len;
    float * ARRAY * ARRAY new_centers;
} args_t;

float global_delta;


/* =============================================================================
 * work
 * =============================================================================
 */
static void
work (args_t* args, int i)
{
    float * ARRAY * ARRAY feature         = args->feature;
    int     nfeatures       = args->nfeatures;
    int     npoints         = args->npoints;
    int     nclusters       = args->nclusters;
    int * ARRAY membership  = args->membership;
    float** clusters        = args->clusters;
    int ** ARRAY   new_centers_len = args->new_centers_len;
    float * ARRAY * ARRAY new_centers     = args->new_centers;
    float delta = 0.0;
    int index;
    int j;

    index = common_findNearestPoint(feature[i],
                                    nfeatures,
                                    clusters,
                                    nclusters);
    /*
     * If membership changes, increase delta by 1.
     * membership[i] cannot be changed by other threads
     */
    if (membership[i] != index) {
        delta += 1.0;
    }

    /* Assign the membership to object i */
    /* membership[i] can't be changed by other thread */
    membership[i] = index;

    /* Update new cluster centers : sum of objects located within */
    *new_centers_len[index] = *new_centers_len[index] + 1;

    //ACCUMULATE
    { atomic
      for (j = 0; j < nfeatures; j++)
          new_centers[index][j] = new_centers[index][j] + feature[i][j];
    } 

    { atomic
      global_delta = global_delta + delta;
    }
}


/* =============================================================================
 * normal_exec
 * =============================================================================
 */

float * * 
normal_exec (//int       nthreads,
             float * * feature,    /* in: [npoints][nfeatures] */
             int          nfeatures,
             int          npoints,
             int          nclusters,
             float        threshold,
             int * membership)
//             random_t* randomPtr) /* out: [npoints] */
    CHECK_TYPE
{
    int i;
    int j;
    int loop = 0;
    int * * ARRAY new_centers_len; /* [nclusters]: no. of points in each cluster */
    float delta;
    float * ARRAY * ARRAY clusters;      /* out: [nclusters][nfeatures] */
    float * ARRAY * ARRAY new_centers;   /* [nclusters][nfeatures] */
    void* alloc_memory = NULL;
    args_t args;


    csolve_assert(nfeatures > 0);

    /* Allocate space for returning variable clusters[] */
    clusters = (float**)malloc(nclusters * sizeof(float*));
    //csolve_assert(clusters);
    clusters[0] = (float*)malloc(nclusters * nfeatures * sizeof(float));
    //csolve_assert(clusters[0]);
    for (i = 1; i < nclusters; i++) {
        clusters[i] = clusters[i-1] + nfeatures;
    }

    /* Randomly pick cluster centers */
    for (i = 0; i < nclusters; i++) {
        int n = nondetrange(0, npoints); //(int)(random_generate(randomPtr) % npoints);
        for (j = 0; j < nfeatures; j++) {
            clusters[i][j] = feature[n][j];
        }
    }

    foreach (i, 0, npoints)
        membership[i] = -1;
    endfor 

    /*
     * Need to initialize new_centers_len and new_centers[0] to all 0.
     * Allocate clusters on different cache lines to reduce false sharing.
     */
    {
        /* JHALA: ORIGINAL CODE, crazy intermingling of int, float array
         * inside a single block.
         *      { int len ; float * ARRAY features } 
         * where the size of the array is dynamic nfeatures -- i.e. dynamic
         * would be nice to support this, but clearly requires big time
         * deferred checks */
        //int cluster_size = sizeof(int) + sizeof(float) * nfeatures;
        //const int cacheLineSize = 32;
        //cluster_size += (cacheLineSize-1) - ((cluster_size-1) % cacheLineSize);
        //alloc_memory = calloc(nclusters, cluster_size);
        //new_centers_len = (int**) malloc(nclusters * sizeof(int*));
        //new_centers = (float**) malloc(nclusters * sizeof(float*));
        ////csolve_assert(alloc_memory && new_centers && new_centers_len);
        //for (i = 0; i < nclusters; i++) {
        //  new_centers_len[i] = (int*)((char*)alloc_memory + cluster_size * i);
        //  new_centers[i] = (float*)((char*)alloc_memory + cluster_size * i + sizeof(int));
        //}
                
        new_centers_len = (int**) malloc(nclusters * sizeof(int*));
        new_centers = (float**) malloc(nclusters * sizeof(float*));
        for (i = 0; i < nclusters; i++) {
          new_centers_len[i] = (int*) malloc(sizeof(int*));
          new_centers[i]     = (float*) malloc(nfeatures * sizeof(float*));
        }

    }

    do {
        delta = 0.0;

        args.feature         = feature;
        args.nfeatures       = nfeatures;
        args.npoints         = npoints;
        args.nclusters       = nclusters;
        args.membership      = membership;
        args.clusters        = clusters;
        args.new_centers_len = new_centers_len;
        args.new_centers     = new_centers;

        global_delta = delta;

        foreach (i, 0, npoints)
          work(&args, i);
        endfor

        delta = global_delta;

        /* Replace old cluster centers with new_centers */
        for (i = 0; i < nclusters; i++) {
            for (j = 0; j < nfeatures; j++) {
                if (new_centers_len[i] > 0) {
                    clusters[i][j] = new_centers[i][j] / *new_centers_len[i];
                }
                new_centers[i][j] = 0.0;   /* set back to 0 */
            }
            *new_centers_len[i] = 0;   /* set back to 0 */
        }

        delta /= npoints;

    } while ((delta > threshold) && (loop++ < 500));

//    free(alloc_memory);
//    free(new_centers);
//    free(new_centers_len);

    return clusters;
}


/* =============================================================================
 *
 * End of normal.c
 *
 * =============================================================================
 */
