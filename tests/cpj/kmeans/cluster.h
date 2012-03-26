/* =============================================================================
 *
 * cluster.h
 *
 * =============================================================================
 *
 * For the license of bayes/sort.h and bayes/sort.c, please see the header
 * of the files.
 * 
 * ------------------------------------------------------------------------
 * 
 * For the license of kmeans, please see kmeans/LICENSE.kmeans
 * 
 * ------------------------------------------------------------------------
 * 
 * For the license of ssca2, please see ssca2/COPYRIGHT
 * 
 * ------------------------------------------------------------------------
 * 
 * For the license of lib/mt19937ar.c and lib/mt19937ar.h, please see the
 * header of the files.
 * 
 * ------------------------------------------------------------------------
 * 
 * For the license of lib/rbtree.h and lib/rbtree.c, please see
 * lib/LEGALNOTICE.rbtree and lib/LICENSE.rbtree
 * 
 * ------------------------------------------------------------------------
 * 
 * Unless otherwise noted, the following license applies to STAMP files:
 * 
 * Copyright (c) 2007, Stanford University
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 * 
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 * 
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in
 *       the documentation and/or other materials provided with the
 *       distribution.
 * 
 *     * Neither the name of Stanford University nor the names of its
 *       contributors may be used to endorse or promote products derived
 *       from this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY STANFORD UNIVERSITY ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL STANFORD UNIVERSITY BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 *
 * =============================================================================
 */


#ifndef CLUSTER_H
#define CLUSTER_H 1

#include "common.h"

/* RJ: UNCOMMENT to verify kmeans.c, RECOMMENT to verify cluster.c */

typedef struct clusters { 
  int REF(V > 0) numAttributes;
  int REF(V > 0) best_nclusters;
  FLOAT2D(best_nclusters, numAttributes) cluster_centres;
} clusters_t;


/* =============================================================================
 * cluster_exec
 * =============================================================================
 */
clusters_t * NNSTART NNVALIDPTR NNROOM_FOR(clusters_t)//OK
cluster_exec (
    //int      nthreads,              /* in: number of threads*/
    int    REF(V > 0) numObjects,     /* number of input objects */
    int    REF(V > 0) numAttributes,  /* size of attribute of each object */
    FLOAT2D(numObjects, numAttributes) attributes,  /* [numObjects][numAttributes] */
    int    use_zscore_transform,
    int    REF(V > 0)  min_nclusters, /* testing k range from min to max */
    int    REF(V >= min_nclusters) max_nclusters,
    float  REF(V > 0) threshold,      /* in:   */
    INTARR(numObjects) cluster_assign /* out: [numObjects] */
) OKEXTERN;
#endif /* CLUSTER_H */


/* =============================================================================
 *
 * End of cluster.h
 *
 * =============================================================================
 */
