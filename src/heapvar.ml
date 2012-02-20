(*
 * Copyright © 1990-2009 The Regents of the University of California. All rights reserved. 
 *
 * Permission is hereby granted, without written agreement and without 
 * license or royalty fees, to use, copy, modify, and distribute this 
 * software and its documentation for any purpose, provided that the 
 * above copyright notice and the following two paragraphs appear in 
 * all copies of this software. 
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY 
 * FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES 
 * ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN 
 * IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY 
 * OF SUCH DAMAGE. 
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES, 
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY 
 * AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS 
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION 
 * TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 *)
module P = Pretty
module M = Misc
  
open Misc.Ops

type t = HVar of int
    
let d_hvar () (HVar n) = P.text <| "h" ^ string_of_int n
    
let compare (HVar n) (HVar m) = compare n m
    
let (fresh_heapvar, reset_fresh_heapvar) = 
  let (fresh_heapvar_id, reset_fresh_heapvar_ids) = Misc.mk_int_factory ()
  in (fresh_heapvar_id <+> (fun i -> HVar i), reset_fresh_heapvar_ids) 
  
type hvar = t
    
module ComparableHeapvar =
  struct
    type t = hvar
    let compare = compare
    let print = CilMisc.pretty_to_format d_hvar
  end
  
module HeapvarMap = 
  Misc.EMap (ComparableHeapvar)
