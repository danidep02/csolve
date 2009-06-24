/*
 * jccoefct.c
 *
 * Copyright (C) 1994, Thomas G. Lane.
 * This file is part of the Independent JPEG Group's software.
 * For conditions of distribution and use, see the accompanying README file.
 *
 * This file contains the coefficient buffer controller for compression.
 * This controller is the top level of the JPEG compressor proper.
 * The coefficient buffer lies between forward-DCT and entropy encoding steps.
 */

#define JPEG_INTERNALS
#include "jinclude.h"
#include "jpeglib.h"

// sm: make type names globally unique
#define my_coef_ptr jccoefct_my_coef_ptr


/* We use a full-image coefficient buffer when doing Huffman optimization,
 * and also for writing multiple-scan JPEG files.  In all cases, the DCT
 * step is run during the first pass, and subsequent passes need only read
 * the buffered coefficients.
 */
#ifdef ENTROPY_OPT_SUPPORTED
#define FULL_COEF_BUFFER_SUPPORTED
#else
#ifdef C_MULTISCAN_FILES_SUPPORTED
#define FULL_COEF_BUFFER_SUPPORTED
#endif
#endif


/* Private buffer controller object */

typedef struct my_coef_controller {
  struct jpeg_c_coef_controller pub; /* public fields */

  JDIMENSION MCU_row_num;	/* keep track of MCU row # within image */

  /* For single-pass compression, it's sufficient to buffer just one MCU
   * (although this may prove a bit slow in practice).  We allocate a
   * workspace of MAX_BLOCKS_IN_MCU coefficient blocks, and reuse it for each
   * MCU constructed and sent.  (On 80x86, the workspace is FAR even though
   * it's not really very big; this is to keep the module interfaces unchanged
   * when a large coefficient buffer is necessary.)
   * In multi-pass modes, this array points to the current MCU's blocks
   * within the virtual arrays.
   */
  JBLOCKROW MCU_buffer[MAX_BLOCKS_IN_MCU];

  /* In multi-pass modes, we need a virtual block array for each component. */
  jvirt_barray_ptr whole_image[MAX_COMPONENTS];
} my_coef_controller;

typedef my_coef_controller * my_coef_ptr;
#pragma ccured_extends("Smy_coef_controller", "Sjpeg_c_coef_controller")


/* Forward declarations */
METHODDEF void compress_data
    JPP((j_compress_ptr cinfo, JSAMPIMAGE input_buf, JDIMENSION *in_mcu_ctr));
#ifdef FULL_COEF_BUFFER_SUPPORTED
METHODDEF void compress_first_pass
    JPP((j_compress_ptr cinfo, JSAMPIMAGE input_buf, JDIMENSION *in_mcu_ctr));
METHODDEF void compress_output
    JPP((j_compress_ptr cinfo, JSAMPIMAGE input_buf, JDIMENSION *in_mcu_ctr));
#endif


/*
 * Initialize for a processing pass.
 */

METHODDEF void
start_pass_coef (j_compress_ptr cinfo, J_BUF_MODE pass_mode)
{
  my_coef_ptr coef = (my_coef_ptr) TC(cinfo->coef);

  coef->MCU_row_num = 0;

  switch (pass_mode) {
  case JBUF_PASS_THRU:
    if (coef->whole_image[0] != NULL)
      ERREXIT(cinfo, JERR_BAD_BUFFER_MODE);
    coef->pub.compress_data = compress_data;
    break;
#ifdef FULL_COEF_BUFFER_SUPPORTED
  case JBUF_SAVE_AND_PASS:
    if (coef->whole_image[0] == NULL)
      ERREXIT(cinfo, JERR_BAD_BUFFER_MODE);
    coef->pub.compress_data = compress_first_pass;
    break;
  case JBUF_CRANK_DEST:
    if (coef->whole_image[0] == NULL)
      ERREXIT(cinfo, JERR_BAD_BUFFER_MODE);
    coef->pub.compress_data = compress_output;
    break;
#endif
  default:
    ERREXIT(cinfo, JERR_BAD_BUFFER_MODE);
    break;
  }
}


/*
 * Process some data in the single-pass case.
 * Up to one MCU row is processed (less if suspension is forced).
 *
 * NB: input_buf contains a plane for each component in image.
 * For single pass, this is the same as the components in the scan.
 */

METHODDEF void
compress_data (j_compress_ptr cinfo,
	       JSAMPIMAGE input_buf, JDIMENSION *in_mcu_ctr)
{
  my_coef_ptr coef = (my_coef_ptr) TC(cinfo->coef);
  JDIMENSION MCU_col_num;	/* index of current MCU within row */
  JDIMENSION last_MCU_col = cinfo->MCUs_per_row - 1;
  JDIMENSION last_MCU_row = cinfo->MCU_rows_in_scan - 1;
  int blkn, bi, ci, yindex, blockcnt;
  JDIMENSION ypos, xpos;
  jpeg_component_info *compptr;

  /* Loop to write as much as one whole MCU row */

  for (MCU_col_num = *in_mcu_ctr; MCU_col_num <= last_MCU_col; MCU_col_num++) {
    /* Determine where data comes from in input_buf and do the DCT thing.
     * Each call on forward_DCT processes a horizontal row of DCT blocks
     * as wide as an MCU; we rely on having allocated the MCU_buffer[] blocks
     * sequentially.  Dummy blocks at the right or bottom edge are filled in
     * specially.  The data in them does not matter for image reconstruction,
     * so we fill them with values that will encode to the smallest amount of
     * data, viz: all zeroes in the AC entries, DC entries equal to previous
     * block's DC value.  (Thanks to Thomas Kinsman for this idea.)
     */
    blkn = 0;
    for (ci = 0; ci < cinfo->comps_in_scan; ci++) {
      compptr = cinfo->cur_comp_info[ci];
      blockcnt = (MCU_col_num < last_MCU_col) ? compptr->MCU_width
					      : compptr->last_col_width;
      xpos = MCU_col_num * compptr->MCU_sample_width;
      ypos = 0;
      for (yindex = 0; yindex < compptr->MCU_height; yindex++) {
	if (coef->MCU_row_num < last_MCU_row ||
	    yindex < compptr->last_row_height) {
	  (*cinfo->fdct->forward_DCT) (cinfo, compptr,
				       input_buf[ci], coef->MCU_buffer[blkn],
				       ypos, xpos, (JDIMENSION) blockcnt);
	  if (blockcnt < compptr->MCU_width) {
	    /* Create some dummy blocks at the right edge of the image. */
	    jzero_far((void FAR *) coef->MCU_buffer[blkn + blockcnt],
		      (compptr->MCU_width - blockcnt) * SIZEOF(JBLOCK));
	    for (bi = blockcnt; bi < compptr->MCU_width; bi++) {
	      coef->MCU_buffer[blkn+bi][0][0] = coef->MCU_buffer[blkn+bi-1][0][0];
	    }
	  }
	} else {
	  /* Create a whole row of dummy blocks at the bottom of the image. */
	  jzero_far((void FAR *) coef->MCU_buffer[blkn],
		    compptr->MCU_width * SIZEOF(JBLOCK));
	  for (bi = 0; bi < compptr->MCU_width; bi++) {
	    coef->MCU_buffer[blkn+bi][0][0] = coef->MCU_buffer[blkn-1][0][0];
	  }
	}
	blkn += compptr->MCU_width;
	ypos += DCTSIZE;
      }
    }
    /* Try to write the MCU.  In event of a suspension failure, we will
     * re-DCT the MCU on restart (a bit inefficient, could be fixed...)
     */
    if (! (*cinfo->entropy->encode_mcu) (cinfo, coef->MCU_buffer))
      break;			/* suspension forced; exit loop */
  }
  if (MCU_col_num > last_MCU_col)
    coef->MCU_row_num++;	/* advance if we finished the row */
  *in_mcu_ctr = MCU_col_num;
}


#ifdef FULL_COEF_BUFFER_SUPPORTED

/*
 * Process some data in the first pass of a multi-pass case.
 * We process the equivalent of one fully interleaved MCU row ("iMCU" row)
 * per call, ie, v_samp_factor block rows for each component in the image.
 * This amount of data is read from the source buffer, DCT'd and quantized,
 * and saved into the virtual arrays.  We also generate suitable dummy blocks
 * as needed at the right and lower edges.  (The dummy blocks are constructed
 * in the virtual arrays, which have been padded appropriately.)  This makes
 * it possible for subsequent passes not to worry about real vs. dummy blocks.
 *
 * We must also emit the data to the entropy encoder.  This is conveniently
 * done by calling compress_output() after we've loaded the current strip
 * of the virtual arrays.
 *
 * NB: input_buf contains a plane for each component in image.  All
 * components are DCT'd and loaded into the virtual arrays in this pass.
 * However, it may be that only a subset of the components are emitted to
 * the entropy encoder during this first pass; be careful about looking
 * at the scan-dependent variables (MCU dimensions, etc).
 */

METHODDEF void
compress_first_pass (j_compress_ptr cinfo,
		     JSAMPIMAGE input_buf, JDIMENSION *in_mcu_ctr)
{
  my_coef_ptr coef = (my_coef_ptr) TC(cinfo->coef);
  JDIMENSION last_MCU_row = cinfo->total_iMCU_rows - 1;
  JDIMENSION blocks_across, MCUs_across, MCUindex;
  int bi, ci, h_samp_factor, block_row, block_rows, ndummy;
  JCOEF lastDC;
  jpeg_component_info *compptr;
  JBLOCKARRAY buffer;
  JBLOCKROW thisblockrow, lastblockrow;

  for (ci = 0, compptr = cinfo->comp_info; ci < cinfo->num_components;
       ci++, compptr++) {
    /* Align the virtual buffer for this component. */
    buffer = (*cinfo->mem->access_virt_barray)
      ((j_common_ptr) TC(cinfo), coef->whole_image[ci],
       coef->MCU_row_num * compptr->v_samp_factor, TRUE);
    /* Count non-dummy DCT block rows in this iMCU row. */
    if (coef->MCU_row_num < last_MCU_row)
      block_rows = compptr->v_samp_factor;
    else {
      block_rows = (int) (compptr->height_in_blocks % compptr->v_samp_factor);
      if (block_rows == 0) block_rows = compptr->v_samp_factor;
    }
    blocks_across = compptr->width_in_blocks;
    h_samp_factor = compptr->h_samp_factor;
    /* Count number of dummy blocks to be added at the right margin. */
    ndummy = (int) (blocks_across % h_samp_factor);
    if (ndummy > 0)
      ndummy = h_samp_factor - ndummy;
    /* Perform DCT for all non-dummy blocks in this iMCU row.  Each call
     * on forward_DCT processes a complete horizontal row of DCT blocks.
     */
    for (block_row = 0; block_row < block_rows; block_row++) {
      thisblockrow = buffer[block_row];
      (*cinfo->fdct->forward_DCT) (cinfo, compptr,
				   input_buf[ci], thisblockrow,
				   (JDIMENSION) (block_row * DCTSIZE),
				   (JDIMENSION) 0, blocks_across);
      if (ndummy > 0) {
	/* Create dummy blocks at the right edge of the image. */
	thisblockrow += blocks_across; /* => first dummy block */
	jzero_far((void FAR *) thisblockrow, ndummy * SIZEOF(JBLOCK));
	lastDC = thisblockrow[-1][0];
	for (bi = 0; bi < ndummy; bi++) {
	  thisblockrow[bi][0] = lastDC;
	}
      }
    }
    /* If at end of image, create dummy block rows as needed.
     * The tricky part here is that within each MCU, we want the DC values
     * of the dummy blocks to match the last real block's DC value.
     * This squeezes a few more bytes out of the resulting file...
     */
    if (coef->MCU_row_num == last_MCU_row) {
      blocks_across += ndummy;	/* include lower right corner */
      MCUs_across = blocks_across / h_samp_factor;
      for (block_row = block_rows; block_row < compptr->v_samp_factor;
	   block_row++) {
	thisblockrow = buffer[block_row];
	lastblockrow = buffer[block_row-1];
	jzero_far((void FAR *) thisblockrow,
		  (size_t) (blocks_across * SIZEOF(JBLOCK)));
	for (MCUindex = 0; MCUindex < MCUs_across; MCUindex++) {
	  lastDC = lastblockrow[h_samp_factor-1][0];
	  for (bi = 0; bi < h_samp_factor; bi++) {
	    thisblockrow[bi][0] = lastDC;
	  }
	  thisblockrow += h_samp_factor; /* advance to next MCU in row */
	  lastblockrow += h_samp_factor;
	}
      }
    }
  }
  /* NB: compress_output will increment MCU_row_num */

  /* Emit data to the entropy encoder, sharing code with subsequent passes */
  compress_output(cinfo, input_buf, in_mcu_ctr);
}


/*
 * Process some data in subsequent passes of a multi-pass case.
 * We process the equivalent of one fully interleaved MCU row ("iMCU" row)
 * per call, ie, v_samp_factor block rows for each component in the scan.
 * The data is obtained from the virtual arrays and fed to the entropy coder.
 *
 * Note that output suspension is not supported during multi-pass operation,
 * so the complete MCU row will always be emitted to the entropy encoder
 * before returning.
 *
 * NB: input_buf is ignored; it is likely to be a NULL pointer.
 */

METHODDEF void
compress_output (j_compress_ptr cinfo,
		 JSAMPIMAGE input_buf, JDIMENSION *in_mcu_ctr)
{
  my_coef_ptr coef = (my_coef_ptr) TC(cinfo->coef);
  JDIMENSION MCU_col_num;	/* index of current MCU within row */
  int blkn, ci, xindex, yindex, yoffset, num_MCU_rows;
  JDIMENSION remaining_rows, start_col;
  JBLOCKARRAY buffer[MAX_COMPS_IN_SCAN];
  JBLOCKROW buffer_ptr;
  jpeg_component_info *compptr;

  /* Align the virtual buffers for the components used in this scan.
   * NB: during first pass, this is safe only because the buffers will
   * already be aligned properly, so jmemmgr.c won't need to do any I/O.
   */
  for (ci = 0; ci < cinfo->comps_in_scan; ci++) {
    compptr = cinfo->cur_comp_info[ci];
    buffer[ci] = (*cinfo->mem->access_virt_barray)
      ((j_common_ptr) cinfo, coef->whole_image[compptr->component_index],
       coef->MCU_row_num * compptr->v_samp_factor, FALSE);
  }

  /* In an interleaved scan, we process exactly one MCU row.
   * In a noninterleaved scan, we need to process v_samp_factor MCU rows,
   * each of which contains a single block row.
   */
  if (cinfo->comps_in_scan == 1) {
    compptr = cinfo->cur_comp_info[0];
    num_MCU_rows = compptr->v_samp_factor;
    /* but watch out for the bottom of the image */
    remaining_rows = cinfo->MCU_rows_in_scan -
		     coef->MCU_row_num * compptr->v_samp_factor;
    if (remaining_rows < (JDIMENSION) num_MCU_rows)
      num_MCU_rows = (int) remaining_rows;
  } else {
    num_MCU_rows = 1;
  }

  /* Loop to process one whole iMCU row */
  for (yoffset = 0; yoffset < num_MCU_rows; yoffset++) {
    for (MCU_col_num = 0; MCU_col_num < cinfo->MCUs_per_row; MCU_col_num++) {
      /* Construct list of pointers to DCT blocks belonging to this MCU */
      blkn = 0;			/* index of current DCT block within MCU */
      for (ci = 0; ci < cinfo->comps_in_scan; ci++) {
	compptr = cinfo->cur_comp_info[ci];
	start_col = MCU_col_num * compptr->MCU_width;
	for (yindex = 0; yindex < compptr->MCU_height; yindex++) {
	  buffer_ptr = buffer[ci][yindex+yoffset] + start_col;
	  for (xindex = 0; xindex < compptr->MCU_width; xindex++) {
	    coef->MCU_buffer[blkn++] = buffer_ptr++;
	  }
	}
      }
      /* Try to write the MCU. */
      if (! (*cinfo->entropy->encode_mcu) (cinfo, coef->MCU_buffer)) {
	ERREXIT(cinfo, JERR_CANT_SUSPEND); /* not supported */
      }
    }
  }

  coef->MCU_row_num++;		/* advance to next iMCU row */
  *in_mcu_ctr = cinfo->MCUs_per_row;
}

#endif /* FULL_COEF_BUFFER_SUPPORTED */


/*
 * Initialize coefficient buffer controller.
 */

GLOBAL void
jinit_c_coef_controller (j_compress_ptr cinfo, boolean need_full_buffer)
{
  my_coef_ptr coef;
  int ci, i;
  jpeg_component_info *compptr;
  JBLOCKROW buffer;

  coef =
    (my_coef_ptr)alloc_small_wrapper((j_common_ptr) TC(cinfo), JPOOL_IMAGE,
                                     SIZEOF(my_coef_controller));
  cinfo->coef = (struct jpeg_c_coef_controller *) TC(coef);
  coef->pub.start_pass = start_pass_coef;

  /* Create the coefficient buffer. */
  if (need_full_buffer) {
#ifdef FULL_COEF_BUFFER_SUPPORTED
    /* Allocate a full-image virtual array for each component, */
    /* padded to a multiple of samp_factor DCT blocks in each direction. */
    /* Note memmgr implicitly pads the vertical direction. */
    for (ci = 0, compptr = cinfo->comp_info; ci < cinfo->num_components;
	 ci++, compptr++) {
      coef->whole_image[ci] = (*cinfo->mem->request_virt_barray)
	((j_common_ptr) TC(cinfo), JPOOL_IMAGE,
	 (JDIMENSION) jround_up((long) compptr->width_in_blocks,
				(long) compptr->h_samp_factor),
	 compptr->height_in_blocks,
	 (JDIMENSION) compptr->v_samp_factor);
    }
#else
    ERREXIT(cinfo, JERR_BAD_BUFFER_MODE);
#endif
  } else {
    /* We only need a single-MCU buffer. */
    buffer =
      (JBLOCKROW)alloc_large_wrapper((j_common_ptr) TC(cinfo), JPOOL_IMAGE,
                                     MAX_BLOCKS_IN_MCU * SIZEOF(JBLOCK));
    for (i = 0; i < MAX_BLOCKS_IN_MCU; i++) {
      coef->MCU_buffer[i] = buffer + i;
    }
    coef->whole_image[0] = NULL; /* flag for no virtual arrays */
  }
}