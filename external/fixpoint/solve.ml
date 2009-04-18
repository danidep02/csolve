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
 *
 *)


(** This module implements a fixpoint solver *)

module P  = Ast.Predicate
module E  = Ast.Expression
module PH = Ast.Predicate.Hash
module Sy = Ast.Symbol
module SM = Sy.SMap
module So = Ast.Sort
module C  = Ast.Constraint

(* JHALA: What the hell is this ? *)

type t = int * TP.t

let make =
  let ct = ref 0 in
  (fun () -> if c > 0 then None else incr c; Some (1, TP.t))


(*************************************************************)
(********************* Stats *********************************)
(*************************************************************)

let stat_refines        = ref 0
let stat_simple_refines = ref 0
let stat_tp_refines     = ref 0
let stat_imp_queries    = ref 0
let stat_valid_queries  = ref 0
let stat_matches        = ref 0

(* Sections :
 * Iterative Refinement
 * Constraint Sat Checking
 * Refinement
 * Constraint Indexing

 * Debug/Profile
 * Stats/Printing
 * Misc Helpers
  
 * TypeDefs 
 * Initial Solution
 * Qual Instantiation
 * Constraint Simplification/Splitting *)

(***************************************************************)
(************************** Refinement *************************)
(***************************************************************)

let is_simple_refatom = function 
  | C.Kvar ([], _) -> true
  | _ -> false

let is_simple_constraint (_,_,(_,ra1s),(_,ra2s),_) = 
  List.for_all is_simple_refatom ra1s &&
  List.for_all is_simple_refatom ra2s &&
  not (!Cf.no_simple || !Cf.verify_simple)

let lhs_preds s env gp r1 =
  let envps = environment_preds s env in
  let r1ps  = refinement_preds  s r1 in
  gp :: (envps ++ r1ps) 

let rhs_cands s = function
  | C.Kvar (xes, k) -> 
      sol_read s k |> 
      List.map (fun q -> ((k,q), apply_substs xes q))
  | _ -> []

let check_tp ctx env lps =  function [] -> [] | rcs ->
  let env = (SM.map fst env)
  let rv  = Misc.do_catch "ERROR: check_tp" 
              (TP.set_and_filter ctx (SM.map fst env) lps) rcs in
  let _   = stat_tp_refines += 1;
            stat_imp_queries += (List.length rcs);
            stat_valid_queries += (List.length rv) in
  rv

let refine ctx s ((env, g, (vv1, ra1s), (vv2, ra2s), _) as c) =
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
    let kqs1    = List.map fst xs in
    (if is_simple_constraint c
     then let _ = stat_simple_refines += 1 in kqs1 
     else kqs1 ++ (check_tp env lps x2))
    |> group_and_update s 

(***************************************************************)
(************************* Satisfaction ************************)
(***************************************************************)

let unsat ctx s ((env, gp, (vv1, ra1s), (vv2, ra2s), _) as c) =
  let _   = asserts (vv1 = vv2) "ERROR: malformed constraint" in
  let lps = lhs_preds s env gp (vv1, ra1s) in
  let rhs = [(0, P.And (Misc.flap (refineatom_preds s) ra2s))] in
  not ((check_tp ctx env lps rhs) = [0])

let unsat_constraints ctx s sri =
  Ci.to_list sri |> List.filter (unsat ctx s)

(**************************************************************)
(****************** Debug/Profile Information *****************)
(**************************************************************)

(* TODO HEREHEREHEREHERE *)

let dump_ref_constraints sri =
  if !Co.dump_ref_constraints then begin
    Format.printf "Refinement Constraints \n";
    Ci.iter sri (fun c -> Format.printf "@[%a@.@]" (pprint_ref None) c);
    printf "@[SCC Ranked Refinement Constraints@.@\n@]";
    sort_iter_ref_constraints sri (fun c -> printf "@[%a@.@]" (pprint_ref None) c);
  end

let dump_ref_vars sri =
  if !Cf.dump_ref_vars then
  (printf "@[Refinement Constraint Vars@.@\n@]";
  iter_ref_constraints sri (fun c -> printf "@[(%d)@ %s@.@]" (ref_id c) 
    (match (ref_k c) with Some k -> Path.unique_name k | None -> "None")))
   
let dump_constraints cs =
  if !Cf.dump_constraints then begin
    printf "******************Frame Constraints****************@.@.";
    let index = ref 0 in
    List.iter (fun {lc_cstr = c; lc_orig = d} -> if (not (is_wfframe_constraint c)) || C.ck_olev C.ol_dump_wfs then 
            (incr index; printf "@[(%d)(%a) %a@]@.@." !index pprint_orig d pprint c)) cs;
    printf "@[*************************************************@]@.@.";
  end

let dump_solution_stats s = 
  if C.ck_olev C.ol_solve_stats then
    let kn  = Sol.length s in
    let (sum, max, min) =   
      (Sol.fold (fun _ qs x -> (+) x (List.length qs)) s 0,
      Sol.fold (fun _ qs x -> max x (List.length qs)) s min_int,
      Sol.fold (fun _ qs x -> min x (List.length qs)) s max_int) in
    C.cprintf C.ol_solve_stats "@[Quals:@\n\tTotal:@ %d@\n\tAvg:@ %f@\n\tMax:@ %d@\n\tMin:@ %d@\n@\n@]"
    sum ((float_of_int sum) /. (float_of_int kn)) max min;
    print_flush ()
  else ()
  
let dump_unsplit cs =
  let cs = if C.ck_olev C.ol_solve_stats then List.rev_map (fun c -> c.lc_cstr) cs else [] in
  let cc f = List.length (List.filter f cs) in
  let (wf, sub) = (cc is_wfframe_constraint, cc is_subframe_constraint) in
  C.cprintf C.ol_solve_stats "@.@[unsplit@ constraints:@ %d@ total@ %d@ wf@ %d@ sub@]@.@." (List.length cs) wf sub

let dump_solving sri s step =
  if step = 0 then 
    let cs   = get_ref_constraints sri in 
    let kn   = Sol.length s in
    let wcn  = List.length (List.filter is_wfref_constraint cs) in
    let rcn  = List.length (List.filter is_subref_constraint cs) in
    let scn  = List.length (List.filter is_simple_constraint cs) in
    let scn2 = List.length (List.filter is_simple_constraint2 cs) in
    (dump_ref_vars sri;
     dump_ref_constraints sri;
     C.cprintf C.ol_solve_stats "@[%d@ variables@\n@\n@]" kn;
     C.cprintf C.ol_solve_stats "@[%d@ split@ wf@ constraints@\n@\n@]" wcn;
     C.cprintf C.ol_solve_stats "@[%d@ split@ subtyping@ constraints@\n@\n@]" rcn;
     C.cprintf C.ol_solve_stats "@[%d@ simple@ subtyping@ constraints@\n@\n@]" scn;
     C.cprintf C.ol_solve_stats "@[%d@ simple2@ subtyping@ constraints@\n@\n@]" scn2;
     dump_solution_stats s) 
  else if step = 1 then
    dump_solution_stats s
  else if step = 2 then
    (C.cprintf C.ol_solve_stats 
      "@[Refine Iterations: %d@ total (= wf=%d + su=%d) sub includes si=%d tp=%d unsatLHS=%d)\n@\n@]"
      !stat_refines !stat_wf_refines  !stat_sub_refines !stat_simple_refines !stat_tp_refines !stat_unsat_lhs;
     C.cprintf C.ol_solve_stats "@[Implication Queries:@ %d@ match;@ %d@ to@ TP@ (%d@ valid)@]@.@." 
       !stat_matches !stat_imp_queries !stat_valid_queries;
     if C.ck_olev C.ol_solve_stats then TP.print_stats std_formatter () else ();
     dump_solution_stats s;
     flush stdout)

let dump_solution s =
  if C.ck_olev C.ol_solve then
    Sol.iter (fun p r -> C.cprintf C.ol_solve "@[%s: %a@]@."
              (Path.unique_name p) (Oprint.print_list Q.pprint C.space) r) s
  else ()

let dump_qualifiers cqs =
  if C.ck_olev C.ol_insane then
    (printf "Raw@ generated@ qualifiers:@.";
    List.iter (fun (c, qs) -> List.iter (fun q -> printf "%a@." Qualifier.pprint q) qs;
                              if not(C.empty_list qs) then printf "@.") cqs;
     printf "done.@.")



(***************************************************************)
(******************** Iterative Refinement *********************)
(***************************************************************)

let rec solve_sub sri s w = 
  (if !stat_refines mod 100 = 0 
   then C.cprintf C.ol_solve "@[num@ refines@ =@ %d@\n@]" !stat_refines);
  match pop_worklist sri w with (None,_) -> s | (Some c, w') ->
    let (r,b,fci) = get_ref_rank sri c in
    let _ = C.cprintf C.ol_solve "@.@[Refining@ %d@ at iter@ %d in@ scc@ (%d,%b,%s):@]@."
            (get_ref_id c) !stat_refines r b (C.io_to_string fci) in
    let _ = if C.ck_olev C.ol_insane then dump_solution s in
    let w' = if BS.time "refine" (refine sri s) c 
             then push_worklist sri w' (get_ref_deps sri c) else w' in
    solve_sub sri s w'

let solve_wf sri s =
  iter_ref_constraints sri 
  (function WFRef _ as c -> ignore (refine sri s c) | _ -> ())

let solve qs env consts cs = 
  let cs = if !Cf.simpguard then List.map simplify_fc cs else cs in
  let _  = dump_constraints cs in
  let _  = dump_unsplit cs in
  let cs = BS.time "splitting constraints" split cs in
  let max_env = List.fold_left 
    (fun env (v, c, _) -> Le.combine (frame_env c.lc_cstr) env) Le.empty cs in
(*  let _ = C.cprintf C.ol_insane "===@.Pruned Maximum Environment@.%a@.===@." pprint_fenv_shp max_env in
  let _ = printf "%a@.@." (pprint_raw_fenv true) max_env; assert false in*)
  let cs = List.map (fun (v, c, cstr) -> (set_labeled_constraint c (make_val_env v max_env), cstr)) cs in
  (* let cs = if !Cf.esimple then 
               BS.time "e-simplification" (List.map esimple) cs else cs in *)
  (*let _ = printf "Qualifier@ patterns@.";
    List.map (fun (_, {Parsetree.pqual_pat_desc = (_, _, p)}) -> printf "%a@." P.pprint_pattern p) qs in*)
  let qs = BS.time "instantiating quals" (instantiate_per_environment env consts cs) qs in
  (*let qs = List.map (fun qs -> List.filter Qualifier.may_not_be_tautology qs) qs in*)
  let _ = if C.ck_olev C.ol_solve then
          C.cprintf C.ol_solve "@[%i@ instantiation@ queries@ %i@ misses@]@." (List.length cs) !tr_misses in
  let _ = if C.ck_olev C.ol_solve then
          C.cprintf C.ol_solve_stats "@[%i@ qualifiers@ generated@]@." (List.length (List.flatten qs)) in
  let _ = if C.ck_olev C.ol_insane then
          dump_qualifiers (List.combine (strip_origins cs) qs) in
(*let _ = assert false in*)
  let sri = BS.time "making ref index" make_ref_index cs in
  let s = BS.time "make initial sol" make_initial_solution (List.combine (strip_origins cs) qs) in
  (*let _ = JS.print stdout "JanStats"; flush stdout in*)

  let _ = dump_solution s in
  let _ = dump_solving sri s 0 in
  let _ = BS.time "solving wfs" (solve_wf sri) s in
  let _ = C.cprintf C.ol_solve "@[AFTER@ WF@]@." in
  let _ = dump_solving sri s 1 in
  let _ = dump_solution s in
  let w = make_initial_worklist sri in
  let _ = BS.time "solving sub" (solve_sub sri s) w in
  let _ = dump_solving sri s 2 in
  let _ = dump_solution s in
  let _ = TP.reset () in
  let unsat = BS.time "testing solution" (unsat_constraints sri) s in
  (*let sat = List.for_all (fun x -> x) (BS.time "testing solution" (List.map (refine sri s)) cs') in*)
  if List.length unsat > 0 then 
    C.cprintf C.ol_solve_error "@[Ref_constraints@ still@ unsatisfied:@\n@]";
    List.iter (fun (c, b) -> C.cprintf C.ol_solve_error "@[%a@.@\n@]" (pprint_ref None) c) unsat;
  (solution_map s, List.map snd unsat)

