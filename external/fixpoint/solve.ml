(*
 * Copyright © 2009 The Regents of the University of California. All rights reserved. 
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
 *)

module TP = TheoremProver

(** This module implements a fixpoint solver *)

module F  = Format
module A  = Ast
module Co = Constants
module P  = A.Predicate
module E  = A.Expression
module S  = A.Sort
module PH = A.Predicate.Hash
module Sy = A.Symbol
module SM = Sy.SMap
module C  = Constraint
module Ci = Cindex

open Misc.Ops

type t = {
  tpc : TP.t;
  sri : Ci.t;
}

(*************************************************************)
(********************* Stats *********************************)
(*************************************************************)

let stat_refines        = ref 0
let stat_simple_refines = ref 0
let stat_tp_refines     = ref 0
let stat_imp_queries    = ref 0
let stat_valid_queries  = ref 0
let stat_matches        = ref 0


(***************************************************************)
(************************** Refinement *************************)
(***************************************************************)

let lhs_preds s env gp r1 =
  let envps = C.environment_preds s env in
  let r1ps  = C.refinement_preds  s r1 in
  gp :: (envps ++ r1ps) 

let rhs_cands s = function
  | C.Kvar (xes, k) -> 
      C.sol_read s k |> 
      List.map (fun q -> ((k,q), C.apply_substs xes q))
  | _ -> []

let check_tp me env lps =  function [] -> [] | rcs ->
  let env = SM.map fst env in
  let rv  = Misc.do_catch "ERROR: check_tp" 
              (TP.set_and_filter me.tpc env lps) rcs in
  let _   = stat_tp_refines += 1;
            stat_imp_queries += (List.length rcs);
            stat_valid_queries += (List.length rv) in
  rv

let refine me s ((env, g, (vv1, ra1s), (vv2, ra2s), _) as c) =
  let _  = asserts (vv1 = vv2) "ERROR: malformed constraint";
           incr stat_refines in
  let lps  = lhs_preds s env g (vv1, ra1s) in
  let rcs  = Misc.flap (rhs_cands s) ra2s in
  if (List.exists P.is_contra lps) || (rcs = []) then
    let _ = stat_matches += (List.length rcs) in
    (false, s)
  else
    let rcs     = List.filter (fun (_,p) -> not (P.is_contra p)) rcs in
    let lt      = PH.create 17 in
    let _       = List.iter (fun p -> PH.add lt p ()) lps in
    let (x1,x2) = List.partition (fun (_,p) -> PH.mem lt p) rcs in
    let _       = stat_matches += (List.length x1) in
    let kqs1    = List.map fst x1 in
    (if C.is_simple c then (stat_simple_refines += 1; kqs1) 
                      else kqs1 ++ (check_tp me env lps x2))
    |> C.group_sol_update s 

(***************************************************************)
(************************* Satisfaction ************************)
(***************************************************************)

let unsat me s (env, gp, (vv1, ra1s), (vv2, ra2s), _) =
  let _    = asserts (vv1 = vv2) "ERROR: malformed constraint" in
  let lps  = lhs_preds s env gp (vv1, ra1s) in
  let rhsp = ra2s |> Misc.flap (C.refineatom_preds s) |> A.pAnd in
  not ((check_tp me env lps [(0, rhsp)]) = [0])

let unsat_constraints me s sri =
  Ci.to_list sri |> List.filter (unsat me s)

(***************************************************************)
(************************ Debugging/Stats **********************)
(***************************************************************)

let dump_solution_stats s = 
  if Co.ck_olev Co.ol_solve_stats then begin
    let (sum, max, min) =   
      (SM.fold (fun _ qs x -> (+) x (List.length qs)) s 0,
       SM.fold (fun _ qs x -> max x (List.length qs)) s min_int,
       SM.fold (fun _ qs x -> min x (List.length qs)) s max_int) in
    let avg = (float_of_int sum) /. (float_of_int (SM.length s)) in
    Format.printf "Quals: \t Total=%d \t Avg=%f \t Max=%d \t Min=%d \n" sum avg max min;
    print_flush ()
  end

let dump_solution s =
  if C.ck_olev C.ol_solve then 
    s |> SM.iter (fun k qs -> 
                    Format.printf "@[%s: %a@]@." k 
                    (Misc.pprint_many false "," P.print) qs) 

let dump me s = function
  | 0 -> 
      let kn   = Sol.length s in
      let cs   = Ci.to_list me.sri in 
      let cn   = List.length cs in
      let scn  = List.length (List.filter C.is_simple cs) in
      Format.printf "%a" Ci.print me.sri;
      Co.cprintf C.ol_solve_stats "# variables   = %d \n" kn;
      Co.cprintf C.ol_solve_stats "# constraints = %d \n" cn;
      Co.cprintf C.ol_solve_stats "# simple constraints = %d \n" scn;
      C.dump_solution_stats s 
  | 1 -> 
      C.dump_solution_stats s
  | 2 ->
      if C.ck_olev C.ol_solve_stats then begin
        F.printf "Refine Iterations = %d (si=%d tp=%d unsatLHS=%d) \n"
          !stat_refines !stat_simple_refines !stat_tp_refines !stat_unsat_lhs;
        F.printf "Queries = %d@ (match= %d, TP=%d, valid=%d)\n" 
          !stat_matches !stat_imp_queries !stat_valid_queries;
        TP.print_stats me.tpc;
        C.dump_solution_stats s;
        flush stdout
      end

(***************************************************************)
(******************** Iterative Refinement *********************)
(***************************************************************)

let rec acsolve me w s = 
  let _ = if !stat_refines mod 100 = 0 
          then Co.cprintf Co.ol_solve "num refines =%d \n" !stat_refines in
  let _ = if Co.ck_olev Co.ol_insane then C.dump_solution s in
  match Ci.pop me.sri si.wkl with (None,_) -> s | (Some c, w') ->
    let ch  = BS.time "refine" (refine me s) c in
    let w'' = if ch then Ci.deps me.sri c |> Ci.push me.sri w' else w' in 
    acsolve me w'' s 

(* API *)
let solve me s = 
  let _ = Format.printf "%a" Ci.print me.sri;  
          C.dump_solution s; 
          dump me s 0 in
  let w = BS.time "init wkl"    Ci.winit me.sri in 
  let _ = BS.time "solving sub" (acsolve me s) w;
          TP.reset ();
          C.dump_solution s; 
          dump me s 2 in
  let u = BS.time "testing solution" (unsat_constraints sri) s in
  let _ = if u != [] then Format.printf "Unsatisfied Constraints:\n %a"
                          (Misc.pprint_many true "\n" (C.print None)) u in
  (s, u)

(* API *)
let create ts ps cs =
  let tpc = TP.create () in
  let _   = BS.time "Adding sorts"     TP.new_sorts tpc ts in
  let _   = BS.time "Adding axioms"   (TP.new_axioms tpc) ps in
  let sri = BS.time "Making ref index" Ci.create cs in
  { tpc = tpc; sri = sri }

(*
(***********************************************************************)
(************** FUTURE WORK:  A Parallel Solver ************************)
(***********************************************************************)

let Par.reduce f = fun (x::xs) -> Par.fold_left f x xs

let one_solve sis s = 
  Par.map (fun si -> Solve.solve si s) sis |> 
  Par.reduce (fun (s,b) (s',b') -> (Constraint.join s s', b || b'))

(* API *)
let psolve n ts axs cs s0 = 
  let css = partition cs n in
  let sis = pmap (Solve.create ts axs) css in
  Misc.fixpoint (one_solve sis) s0
*)
