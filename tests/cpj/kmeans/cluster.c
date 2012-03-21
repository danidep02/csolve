/* =============================================================================
 *
 * cluster.c
 *
 * =============================================================================
 *
 * Description:
 *
 * Takes as input a file, containing 1 data point per per line, and performs a
 * fuzzy c-means clustering on the data. Fuzzy clustering is performed using
 * min to max clusters and the clustering that gets the best score according to
 * a compactness and separation criterion are returned.
 *
 *
 * Author:
 *
 * Brendan McCane
 * James Cook University of North Queensland. Australia.
 * email: mccane@cs.jcu.edu.au
 *
 *
 * Edited by:
 *
 * Jay Pisharath, Wei-keng Liao
 * Northwestern University
 *
 * Chi Cao Minh
 * Stanford University
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


#include <assert.h>
#include <float.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "common.h"
#include "cluster.h"
#include "normal.h"
//#include "random.h"
#include "util.h"
//#include "tm.h"


/* =============================================================================
 * extractMoments
 * =============================================================================
 */
static float* ARRAY START VALIDPTR SIZE_GE(4*num_moments)
extractMoments (float * ARRAY START VALIDPTR SIZE_GE(4*num_elts) data,
                int     REF(V >= 0)                         num_elts, 
                int     REF(V >= 0)                      num_moments)
{
    int i;
    int j;
    float* moments;

    moments = (float*)calloc(num_moments, sizeof(float));
    
    assert(moments);
    for (i = 0; i < num_elts; i++) {
        moments[0] += data[i];
    }

    moments[0] = moments[0] / num_elts;
    for (j = 1; j < num_moments; j++) {
        moments[j] = 0;
        for (i = 0; i < num_elts; i++) {
            moments[j] += pow((data[i]-moments[0]), j+1);
        }
        moments[j] = moments[j] / num_elts;
    }
    return moments;
}


/* =============================================================================
 * zscoreTransform
 * =============================================================================
 */
static void
zscoreTransform (float* ARRAY START VALIDPTR SIZE_GE(4*numAttributes)
                      * ARRAY START VALIDPTR SIZE_GE(4*numObjects) data, /* in & out: [numObjects][numAttributes] */
                 int    REF(V > 0)                          numObjects,
                 int    REF(V > 0)                       numAttributes)
{
    float* single_variable;
    float* moments;
    int i;
    int j;

    single_variable = (float*)calloc(numObjects, sizeof(float));
    assert(single_variable);
    for (i = 0; i < numAttributes; i++) {
        for (j = 0; j < numObjects; j++) {
            single_variable[j] = data[j][i];
        }
        moments = extractMoments(single_variable, numObjects, 2);
        moments[1] = (float)sqrt((double)moments[1]);
        for (j = 0; j < numObjects; j++) {
            data[j][i] = (data[j][i]-moments[0])/moments[1];
        }
        free(moments);
    }
    free(single_variable);
}

/* =============================================================================
 * cluster_exec
 * =============================================================================
 */
int
cluster_exec (
    //int      nthreads,              /* in: number of threads*/
    int    REF(V > 0) numObjects,     /* number of input objects */
    int    REF(V > 0) numAttributes,  /* size of attribute of each object */
    float* START ARRAY VALIDPTR SIZE_GE(4*numAttributes)
         * START ARRAY VALIDPTR SIZE_GE(4*numObjects) attributes, /* [numObjects][numAttributes] */
    int    use_zscore_transform,
    int    REF(V > 0)  min_nclusters, /* testing k range from min to max */
    int    REF(V >= min_nclusters) max_nclusters,
    float  REF(V > 0) threshold,      /* in:   */
    int    /*FINAL abakst: Hrm, this needs to be dealt with*/ 
           REF(&&[V >= min_nclusters;V <= max_nclusters])     
          *best_nclusters,     /* out: number between min and max */
    float* ARRAY START VALIDPTR SIZE_GE(4*numAttributes) 
         * ARRAY NNSTART NNVALIDPTR SIZE_GE(4*min_nclusters)
         /* abakst: this is actually what we want:
	    SIZE_GE(4*DEREF([best_nclusters])) */
         * START VALIDPTR ROOM_FOR(float**) cluster_centres,    /* out: [best_nclusters][numAttributes] */
    int*   ARRAY VALIDPTR SIZE_GE(4*numObjects) cluster_assign       /* out: [numObjects] */
) CHECK_TYPE 
{
    int itime;
    int nclusters;
    int* membership = 0;
    float** tmp_cluster_centres;
    //random_t* randomPtr;

    membership = malloc(numObjects * sizeof(int));
    assert(membership);

    //randomPtr = random_alloc();
    //assert(randomPtr);

    if (use_zscore_transform) {
        zscoreTransform(attributes, numObjects, numAttributes);
    }

    itime = 0;

    /*
     * From min_nclusters to max_nclusters, find best_nclusters
     */
    for (nclusters = min_nclusters; nclusters <= max_nclusters; nclusters++) {

        //random_seed(randomPtr, 7);

        tmp_cluster_centres = normal_exec(//nthreads,
                                          attributes,
                                          numAttributes,
                                          numObjects,
                                          nclusters,
                                          threshold,
                                          membership);
                                          //randomPtr);

	/* if (*cluster_centres) { */
	/*   for (int i = 0; i < nclusters - 1; i++) */
	/*     free((*cluster_centres)[i]); */
	/*   free(*cluster_centres); */
	/* } */

	*cluster_centres = tmp_cluster_centres;
	*best_nclusters = nclusters;

        itime++;
    } /* nclusters */

    free(membership);
    //random_free(randomPtr);

    return 0;
}

/* =============================================================================
 *
 * End of cluster.c
 *
 * =============================================================================
 */
