(* $Id: gutil.mli,v 5.34 2007-01-19 01:53:16 ddr Exp $ *)
(* Copyright (c) 1998-2007 INRIA *)

open Def
open Gwdb

val spouse : iper -> family -> iper

val person_not_a_key_find_all : base -> string -> iper list
val person_ht_find_all : base -> string -> iper list
val person_of_string_key : base -> string -> iper option
val find_same_name : base -> person -> person list
(* Pour les personnes avec plein de '.' dans le prénom ou le nom. *)
val person_of_string_dot_key : base -> string -> iper option

val designation : base -> person -> string

val sort_person_list : base -> person list -> person list

val couple : bool -> 'a -> 'a -> 'a gen_couple

val find_free_occ : base -> string -> string -> int -> int
