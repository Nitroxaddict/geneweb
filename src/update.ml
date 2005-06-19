(* camlp4r ./pa_html.cmo *)
(* $Id: update.ml,v 4.42 2005-06-19 04:46:59 ddr Exp $ *)
(* Copyright (c) 1998-2005 INRIA *)

open Config;
open Def;
open Gutil;
open Util;

exception ModErr;
type create_info = (option date * string * death * option date * string);
type create = [ Create of sex and option create_info | Link ];
type key = (string * string * int * create * string);

value infer_death conf birth =
  match birth with
  [ Some (Dgreg d _) ->
      let a = Gutil.year_of (Gutil.time_gone_by d conf.today) in
      if a > 120 then DeadDontKnowWhen
      else if a <= 80 then NotDead
      else DontKnowIfDead
  | _ -> DontKnowIfDead ]
;

value print_same_name conf base p =
  match Gutil.find_same_name base p with
  [ [_] -> ()
  | pl ->
      do {
        html_p conf;
        Wserver.wprint "%s:\n"
          (capitale (transl conf "persons having the same name"));
        tag "ul" begin
          List.iter
            (fun p ->
               do {
                 html_li conf;
                 stag "a" "href=\"%s%s\"" (commd conf) (acces conf base p)
                 begin
                   Wserver.wprint "%s.%d %s" (p_first_name base p) p.occ
                     (p_surname base p);
                 end;
                 Wserver.wprint "%s\n" (Date.short_dates_text conf base p)
               })
            pl;
        end
      } ]
;

value print_return conf =
  tag "p" begin
    tag "form" "method=\"post\" action=\"%s\"" conf.command begin
      List.iter
        (fun (x, v) ->
           xtag "input" "type=\"hidden\" name=\"%s\" value=\"%s\"" x
             (quote_escaped (decode_varenv v)))
        (conf.henv @ conf.env);
      xtag "input" "type=\"hidden\" name=\"return\" value=\"on\"";
      xtag "input" "type=\"submit\" value=\"%s\""
        (capitale (transl conf "back"));
    end;
  end
;

value print_err_unknown conf base (f, s, o) =
  let title _ = Wserver.wprint "%s" (capitale (transl conf "error")) in
  do {
    rheader conf title;
    Wserver.wprint "%s: <strong>%s.%d %s</strong>\n"
      (capitale (transl conf "unknown person")) f o s;
    print_return conf;
    trailer conf;
    raise ModErr
  }
;

value insert_string base s =
  try base.func.index_of_string s with
  [ Not_found ->
      let i = Adef.istr_of_int base.data.strings.len in
      do { base.func.patch_string i s; i } ]
;

value update_misc_names_of_family base p u =
  match p.sex with
  [ Male ->
      List.iter
        (fun ifam ->
           let des = doi base ifam in
           let cpl = coi base ifam in
           List.iter
             (fun ip ->
                List.iter
                  (fun name ->
                     if not (List.memq ip (person_ht_find_all base name)) then
                       person_ht_add base name ip
                     else ())
                  (person_misc_names base (poi base ip)))
             [mother cpl :: Array.to_list des.children])
        (Array.to_list u.family)
  | _ -> () ]
;

value delete_topological_sort_v conf base =
  let bfile = Util.base_path [] (conf.bname ^ ".gwb") in
  do {
    let tstab_file = Filename.concat bfile "tstab_visitor" in
    try Sys.remove tstab_file with [ Sys_error _ -> () ];
    let tstab_file = Filename.concat bfile "restrict" in
    try Sys.remove tstab_file with [ Sys_error _ -> () ]
  }
;

value delete_topological_sort conf base =
  let _ = delete_topological_sort_v conf base in
  let bfile = Util.base_path [] (conf.bname ^ ".gwb") in
  let tstab_file = Filename.concat bfile "tstab" in
  try Sys.remove tstab_file with [ Sys_error _ -> () ]
;

value print_someone conf base p =
  Wserver.wprint "%s%s %s" (p_first_name base p)
    (if p.occ = 0 then "" else "." ^ string_of_int p.occ) (p_surname base p)
;

value print_first_name conf base p =
  Wserver.wprint "%s%s" (p_first_name base p)
    (if p.occ = 0 then "" else "." ^ string_of_int p.occ)
;

value print_someone_strong conf base p =
  Wserver.wprint "<strong>%s%s %s</strong>" (p_first_name base p)
    (if p.occ = 0 then "" else "." ^ string_of_int p.occ) (p_surname base p)
;

value print_first_name_strong conf base p =
  Wserver.wprint "<strong>%s%s</strong>" (p_first_name base p)
    (if p.occ = 0 then "" else "." ^ string_of_int p.occ)
;

value print_error conf base =
  fun
  [ AlreadyDefined p ->
      Wserver.wprint
        (fcapitale (ftransl conf "name %s already used by %tthis person%t"))
        ("\"" ^ p_first_name base p ^ "." ^ string_of_int p.occ ^ " " ^
           p_surname base p ^ "\"")
        (fun _ ->
           Wserver.wprint "<a href=\"%s%s\">" (commd conf)
             (acces conf base p))
        (fun _ -> Wserver.wprint "</a>.")
  | OwnAncestor p ->
      do {
        print_someone_strong conf base p;
        Wserver.wprint "\n%s" (transl conf "would be his/her own ancestor")
      }
  | BadSexOfMarriedPerson p ->
      Wserver.wprint "%s."
        (capitale (transl conf "cannot change sex of a married person")) ]
;

value print_someone_ref conf base p =
  Wserver.wprint "<a href=\"%s%s\">\n%s%s %s</a>" (commd conf)
    (acces conf base p) (p_first_name base p)
    (if p.occ = 0 then "" else "." ^ string_of_int p.occ) (p_surname base p)
;

value someone_ref_text conf base p =
  "<a href=\"" ^ commd conf ^ acces conf base p ^ "\">\n" ^
    p_first_name base p ^
    (if p.occ = 0 then "" else "." ^ string_of_int p.occ) ^ " " ^
    p_surname base p ^ "</a>"
;

value print_first_name_ref conf base p =
  Wserver.wprint "%s" (someone_ref_text conf base p)
;

value print_warning conf base =
  fun
  [ BirthAfterDeath p ->
      Wserver.wprint (ftransl conf "%t died before his/her birth")
        (fun _ ->
           do {
             print_someone_strong conf base p;
             Wserver.wprint "%s" (Date.short_dates_text conf base p)
           })
  | IncoherentSex p _ _ ->
      Wserver.wprint
        (fcapitale
           (ftransl conf "%t's sex is not coherent with his/her relations"))
        (fun _ -> print_someone_strong conf base p)
  | ChangedOrderOfChildren ifam des before ->
      let cpl = coi base ifam in
      let fath = poi base (father cpl) in
      let moth = poi base (mother cpl) in
      do {
        Wserver.wprint "%s\n"
          (capitale (transl conf "changed order of children"));
        Wserver.wprint "-&gt;\n";
        Wserver.wprint "%s"
          (someone_ref_text conf base fath ^ "\n" ^ transl_nth conf "and" 0 ^
             someone_ref_text conf base moth ^ "\n");
        Wserver.wprint "\n<ul>\n";
        html_li conf;
        Wserver.wprint "%s:\n" (capitale (transl conf "before"));
        Wserver.wprint "\n";
        tag "ul" begin
          Array.iter
            (fun ip ->
               let p = poi base ip in
               do {
                 html_li conf;
                 if p.surname = fath.surname then print_first_name conf base p
                 else print_someone conf base p;
                 Wserver.wprint "%s" (Date.short_dates_text conf base p);
                 Wserver.wprint "\n"
               })
            before;
        end;
        html_li conf;
        Wserver.wprint "%s:\n" (capitale (transl conf "after"));
        Wserver.wprint "\n";
        tag "ul" begin
          Array.iter
            (fun ip ->
               let p = poi base ip in
               do {
                 html_li conf;
                 if p.surname = fath.surname then
                   print_first_name_ref conf base p
                 else print_someone_ref conf base p;
                 Wserver.wprint "%s" (Date.short_dates_text conf base p);
                 Wserver.wprint "\n"
               })
            des.children;
        end;
        Wserver.wprint "</ul>"
      }
  | ChildrenNotInOrder ifam des elder x ->
      let cpl = coi base ifam in
      do {
        Wserver.wprint
          (fcapitale
             (ftransl conf
                "the following children of %t and %t are not in order"))
          (fun _ -> print_someone_strong conf base (poi base (father cpl)))
          (fun _ -> print_someone_strong conf base (poi base (mother cpl)));
        Wserver.wprint ":\n";
        Wserver.wprint "<ul>\n";
        html_li conf;
        print_first_name_strong conf base elder;
        Wserver.wprint "%s" (Date.short_dates_text conf base elder);
        Wserver.wprint "\n";
        html_li conf;
        print_first_name_strong conf base x;
        Wserver.wprint "%s" (Date.short_dates_text conf base x);
        Wserver.wprint "</ul>"
      }
  | DeadTooEarlyToBeFather father child ->
      Wserver.wprint
        (ftransl conf "\
%t is born more than 2 years after the death of his/her father %t")
        (fun _ ->
           do {
             print_someone_strong conf base child;
             Wserver.wprint "%s" (Date.short_dates_text conf base child)
           })
        (fun _ ->
           do {
             print_someone_strong conf base father;
             Wserver.wprint "%s" (Date.short_dates_text conf base father)
           })
  | MarriageDateAfterDeath p ->
      Wserver.wprint
        (fcapitale (ftransl conf "marriage of %t after his/her death"))
        (fun _ ->
           do {
             print_someone_strong conf base p;
             Wserver.wprint "%s" (Date.short_dates_text conf base p)
           })
  | MarriageDateBeforeBirth p ->
      Wserver.wprint
        (fcapitale (ftransl conf "marriage of %t before his/her birth"))
        (fun _ ->
           do {
             print_someone_strong conf base p;
             Wserver.wprint "%s" (Date.short_dates_text conf base p)
           })
  | MotherDeadAfterChildBirth mother child ->
      Wserver.wprint
        (ftransl conf "%t is born after the death of his/her mother %t")
        (fun _ ->
           do {
             print_someone_strong conf base child;
             Wserver.wprint "%s" (Date.short_dates_text conf base child)
           })
        (fun _ ->
           do {
             print_someone_strong conf base mother;
             Wserver.wprint "%s" (Date.short_dates_text conf base mother)
           })
  | ParentBornAfterChild p c ->
      do {
        print_someone_strong conf base p;
        Wserver.wprint "\n%s\n" (transl conf "is born after his/her child");
        print_someone_strong conf base c
      }
  | ParentTooYoung p a ->
      do {
        print_someone_strong conf base p;
        Wserver.wprint "\n%s\n" (transl conf "is a very young parent");
        Wserver.wprint "(%s)" (Date.string_of_age conf a);
      }
  | TitleDatesError p t ->
      Wserver.wprint
        (fcapitale (ftransl conf "%t has incorrect title dates: %t"))
        (fun _ ->
           do {
             print_someone_strong conf base p;
             Wserver.wprint "%s" (Date.short_dates_text conf base p)
           })
        (fun _ ->
           Wserver.wprint "<strong>%s %s</strong> <em>%s-%s</em>"
             (sou base t.t_ident) (sou base t.t_place)
             (match Adef.od_of_codate t.t_date_start with
              [ Some d -> Date.string_of_date conf d
              | _ -> "" ])
             (match Adef.od_of_codate t.t_date_end with
              [ Some d -> Date.string_of_date conf d
              | _ -> "" ]))
  | UndefinedSex p ->
      Wserver.wprint (fcapitale (ftransl conf "undefined sex for %t"))
        (fun _ -> print_someone_strong conf base p)
  | YoungForMarriage p a ->
      do {
        print_someone_strong conf base p;
        Wserver.wprint "\n";
        Wserver.wprint (ftransl conf "married at age %t")
          (fun _ -> Wserver.wprint "%s" (Date.string_of_age conf a))
      } ]
;

value print_warnings conf base wl =
  if wl = [] then ()
  else do {
    html_p conf;
    Wserver.wprint "%s\n" (capitale (transl conf "warnings"));
    tag "ul" begin
      List.iter
        (fun w ->
           do {
             html_li conf; print_warning conf base w; Wserver.wprint "\n"
           })
        wl;
    end
  }
;

value error conf base x =
  let title _ = Wserver.wprint "%s" (capitale (transl conf "error")) in
  do {
    rheader conf title;
    print_error conf base x;
    Wserver.wprint "\n";
    print_return conf;
    trailer conf;
    raise ModErr
  }
;

value error_locked conf =
  let title _ = Wserver.wprint "%s" (capitale (transl conf "error")) in
  do {
    rheader conf title;
    Wserver.wprint
      (fcapitale
         (ftransl conf "the file is temporarily locked: please try again"));
    Wserver.wprint ".\n";
    trailer conf
  }
;

value error_digest conf =
  let title _ = Wserver.wprint "%s" (capitale (transl conf "error")) in
  do {
    rheader conf title;
    print_link_to_welcome conf True;
    Wserver.wprint
      (fcapitale
         (ftransl conf "\
the base has changed; do \"back\", \"reload\", and refill the form"));
    Wserver.wprint ".\n";
    trailer conf;
    raise ModErr
  }
;

value digest_person (p : person) = Iovalue.digest p;
value digest_family (fam : family) (cpl : couple) (des : descend) =
  Iovalue.digest (fam, cpl, des)
;

value get var key env =
  match p_getenv env (var ^ "_" ^ key) with
  [ Some v -> v
  | None -> failwith (var ^ "_" ^ key ^ " unbound") ]
;

value get_number var key env = p_getint env (var ^ "_" ^ key);

value bad_date conf d =
  let title _ = Wserver.wprint "%s" (capitale (transl conf "error")) in
  do {
    rheader conf title;
    Wserver.wprint "%s:\n" (capitale (transl conf "incorrect date"));
    match d with
    [ {day = 0; month = 0; year = a} -> Wserver.wprint "%d" a
    | {day = 0; month = m; year = a} -> Wserver.wprint "%d/%d" m a
    | {day = j; month = m; year = a} -> Wserver.wprint "%d/%d/%d" j m a ];
    trailer conf;
    raise ModErr
  }
;

value int_of_field s =
  try Some (int_of_string (strip_spaces s)) with [ Failure _ -> None ]
;

value reconstitute_date_dmy conf var =
  let (prec, y) =
    let y = get var "yyyy" conf.env in
    let prec = p_getenv conf.env (var ^ "_prec") in
    let len = String.length y in
    if len > 1 then
      match (y.[0], y.[len-1]) with
      [ ('?', _) -> (Some "maybe", String.sub y 1 (len - 1))
      | ('~', _) -> (Some "about", String.sub y 1 (len - 1))
      | ('/', '/') -> (Some "about", String.sub y 1 (len - 2))
      | ('<', _) | ('/', _) -> (Some "before", String.sub y 1 (len - 1))
      | ('>', _) -> (Some "after", String.sub y 1 (len - 1))
      | (_, '/') -> (Some "after", String.sub y 0 (len - 1))
      | _ -> (prec, y) ]
    else (prec, y)
  in
  let (force_f_cal, m) =
    let m = get var "mm" conf.env in
    match String.uppercase m with
    [ "VD" -> (True, Some 1)
    | "BR" -> (True, Some 2)
    | "FM" -> (True, Some 3)
    | "NI" -> (True, Some 4)
    | "PL" -> (True, Some 5)
    | "VT" -> (True, Some 6)
    | "GE" -> (True, Some 7)
    | "FL" -> (True, Some 8)
    | "PR" -> (True, Some 9)
    | "ME" -> (True, Some 10)
    | "TH" -> (True, Some 11)
    | "FT" -> (True, Some 12)
    | "JC" -> (True, Some 13)
    | _ -> (False, int_of_field m) ]
  in
  let d =
    match int_of_field y with
    [ Some y ->
        let prec =
          match prec with
          [ Some "about" -> About
          | Some "maybe" -> Maybe
          | Some "before" -> Before
          | Some "after" -> After
          | Some "oryear" ->
              match get_number var "oryear" conf.env with
              [ Some y -> OrYear y
              | None -> Sure ]
          | Some "yearint" ->
              match get_number var "oryear" conf.env with
              [ Some y -> YearInt y
              | None -> Sure ]
          | _ -> Sure ]
        in
        match m with
        [ Some m ->
            match get_number var "dd" conf.env with
            [ Some d ->
                let d =
                  {day = d; month = m; year = y; prec = prec; delta = 0}
                in
                if d.day >= 1 && d.day <= 31 && d.month >= 1 &&
                   d.month <= 13 then
                  Some d
                else bad_date conf d
            | None ->
                let d =
                  {day = 0; month = m; year = y; prec = prec; delta = 0}
                in
                if d.month >= 1 && d.month <= 13 then Some d
                else bad_date conf d ]
        | None -> Some {day = 0; month = 0; year = y; prec = prec; delta = 0} ]
    | None -> None ]
  in
  (d, force_f_cal)
;

value check_greg_day conf d =
  if d.day > nb_days_in_month d.month d.year then bad_date conf d else ()
;

value reconstitute_date conf var =
  match reconstitute_date_dmy conf var with
  [ (Some d, False) ->
      let (d, cal) =
        match p_getenv conf.env (var ^ "_cal") with
        [ Some "G" | None -> do { check_greg_day conf d; (d, Dgregorian) }
        | Some "J" -> (Calendar.gregorian_of_julian d, Djulian)
        | Some "F" -> (Calendar.gregorian_of_french d, Dfrench)
        | Some "H" -> (Calendar.gregorian_of_hebrew d, Dhebrew)
        | _ -> (d, Dgregorian) ]
      in
      Some (Dgreg d cal)
  | (Some d, True) -> Some (Dgreg (Calendar.gregorian_of_french d) Dfrench)
  | (None, _) ->
      match p_getenv conf.env (var ^ "_text") with
      [ Some txt ->
          let txt = strip_spaces (get var "text" conf.env) in
          if txt = "" then None else Some (Dtext txt)
      | _ -> None ] ]
;

value rec parse_int n =
  parser
  [ [: `('0'..'9' as i); s :] ->
      parse_int (10 * n + Char.code i - Char.code '0') s
  | [: :] -> n ]
;

value parse_r_parent = parser [ [: `'f' :] -> 0 | [: `'m' :] -> 1 ];

value text_of_var conf =
  fun
  [ "pa1" -> transl_nth conf "him/her" 0
  | "pa2" -> transl_nth conf "him/her" 1
  | var ->
      match Stream.of_string var with parser
      [ [: `'r'; pos = parse_int 0; `'_'; pn = parse_r_parent :] ->
          transl_nth conf "relation/relations" 0 ^ " " ^ string_of_int pos ^
            " - " ^ transl_nth conf "father/mother" pn
      | [: `'w'; `'i'; `'t'; `'n'; pos = parse_int 0 :] ->
          transl_nth conf "witness/witnesses" 0 ^ " " ^ string_of_int pos
      | [: `'c'; `'h'; pos = parse_int 0 :] ->
          transl_nth conf "child/children" 0 ^ " " ^ string_of_int pos
      | [: :] -> var ] ]
;

value print_create_conflict conf base p var =
  let text = text_of_var conf var in
  let title _ = Wserver.wprint "%s" (capitale (transl conf "error")) in
  do {
    rheader conf title;
    Wserver.wprint
      (fcapitale (ftransl conf "name %s already used by %tthis person%t"))
      ("\"" ^ p_first_name base p ^ "." ^ string_of_int p.occ ^ " " ^
         p_surname base p ^ "\" (" ^ text ^ ")")
      (fun _ ->
         Wserver.wprint "<a href=\"%s%s\">" (commd conf) (acces conf base p))
      (fun _ -> Wserver.wprint "</a>.");
    html_p conf;
    let free_n =
      find_free_occ base (p_first_name base p) (p_surname base p) 0
    in
    html_p conf;
    tag "form" "method=\"post\" action=\"%s\"" conf.command begin
      List.iter
        (fun (x, v) ->
           xtag "input" "type=\"hidden\" name=\"%s\" value=\"%s\"" x
             (quote_escaped (decode_varenv v)))
        (conf.henv @ conf.env);
      xtag "input" "type=\"hidden\" name=\"field\" value=\"%s\"" var;
      xtag "input" "type=\"hidden\" name=\"free_occ\" value=\"%d\"" free_n;
      tag "ul" begin
        html_li conf;
        Wserver.wprint "%s: %d. \n"
          (capitale (transl conf "first free number")) free_n;
        Wserver.wprint (fcapitale (ftransl conf "click on \"%s\""))
          (transl conf "create");
        Wserver.wprint "%s." (transl conf " to try again with this number");
        html_li conf;
        Wserver.wprint "%s " (capitale (transl conf "or"));
        Wserver.wprint (ftransl conf "click on \"%s\"") (transl conf "back");
        Wserver.wprint " %s %s." (transl_nth conf "and" 0)
          (transl conf "change it (the number) yourself");
        html_li conf;
        Wserver.wprint "%s " (capitale (transl conf "or"));
        Wserver.wprint (ftransl conf "click on \"%s\"") (transl conf "back");
        Wserver.wprint " %s %s." (transl_nth conf "and" 0)
          (transl conf "use \"link\" instead of \"create\"");
      end;
      xtag "input" "type=\"submit\" name=\"create\" value=\"%s\""
        (capitale (transl conf "create"));
      xtag "input" "type=\"submit\" name=\"return\" value=\"%s\""
        (capitale (transl conf "back"));
    end;
    print_same_name conf base p;
    trailer conf;
    raise ModErr
  }
;

value add_misc_names_for_new_persons base new_persons =
  List.iter
    (fun p ->
       List.iter (fun n -> person_ht_add base n p.cle_index)
         (person_misc_names base p))
    new_persons
;

value insert_person conf base src new_persons (f, s, o, create, var) =
  let f = if f = "" then "?" else f in
  let s = if s = "" then "?" else s in
  match create with
  [ Create sex info ->
      try
        if f = "?" || s = "?" then
          if o <= 0 || o >= base.data.persons.len then raise Not_found
          else
            let ip = Adef.iper_of_int o in
            let p = poi base ip in
            if p_first_name base p = f && p_surname base p = s then ip
            else raise Not_found
        else
          let ip = person_ht_find_unique base f s o in
          print_create_conflict conf base (poi base ip) var
      with
      [ Not_found ->
          let o = if f = "?" || s = "?" then 0 else o in
          let ip = Adef.iper_of_int base.data.persons.len in
          let empty_string = insert_string base "" in
          let (birth, birth_place, baptism, baptism_place) =
            match info with
            [ Some (b, bpl, _, _, _) ->
                if String.length bpl >= 2 && String.sub bpl 0 2 = "b/" then
                  (None, "", b, String.sub bpl 2 (String.length bpl - 2))
                else (b, bpl, None, "")
            | None -> (None, "", None, "") ]
          in
          let (death, death_place) =
            match info with
            [ Some (_, _, _, Some d, dpl) ->
                (Death Unspecified (Adef.cdate_of_date d), dpl)
            | Some (_, _, _, None, dpl) when dpl <> "" ->
                (DeadDontKnowWhen, dpl)
            | Some (_, _, (DeadDontKnowWhen | NotDead as dead), None, dpl) ->
                (dead, dpl)
            | _ -> (infer_death conf birth, "") ]
          in
          let p =
            {first_name = insert_string base f;
             surname = insert_string base s; occ = o; image = empty_string;
             first_names_aliases = []; surnames_aliases = [];
             public_name = empty_string; qualifiers = []; aliases = [];
             titles = []; rparents = []; related = [];
             occupation = empty_string; sex = sex; access = IfTitles;
             birth = Adef.codate_of_od birth;
             birth_place = insert_string base birth_place;
             birth_src = empty_string; baptism = Adef.codate_of_od baptism;
             baptism_place = insert_string base baptism_place;
             baptism_src = empty_string;
             death = death; death_place = insert_string base death_place;
             death_src = empty_string; burial = UnknownBurial;
             burial_place = empty_string; burial_src = empty_string;
             notes = empty_string;
             psources =
               if f = "?" || s = "?" then empty_string
               else insert_string base (only_printable src);
             cle_index = ip}
          and a = no_ascend ()
          and u = {family = [| |]} in
          do {
            base.func.patch_person p.cle_index p;
            base.func.patch_ascend p.cle_index a;
            base.func.patch_union p.cle_index u;
            if f <> "?" && s <> "?" then do {
              person_ht_add base (nominative (f ^ " " ^ s)) ip;
              new_persons.val := [p :: new_persons.val]
            }
            else ();
            ip
          } ]
  | Link ->
      if f = "?" || s = "?" then
        if o < 0 || o >= base.data.persons.len then
          print_err_unknown conf base (f, s, o)
        else
          let ip = Adef.iper_of_int o in
          let p = poi base ip in
          if p_first_name base p = f && p_surname base p = s then ip
          else print_err_unknown conf base (f, s, o)
      else
        try person_ht_find_unique base f s o with
        [ Not_found -> print_err_unknown conf base (f, s, o) ] ]
;

value rec update_conf_env field p occ o_env n_env =
  let get_name (n, v) = n in
  match o_env with
  [ [] -> n_env
  | [head :: rest] ->
      let name = get_name head in
      if name = field ^ "p" then
        update_conf_env field p occ rest [(name, p) :: n_env]
      else if name = field ^ "occ" then
        update_conf_env field p occ rest [(name, occ) :: n_env]
      else if
        name = "link" || name = "create" || name = "free_occ" ||
        name = "field" || name = "link_occ" then
        update_conf_env field p occ rest n_env
      else update_conf_env field p occ rest [head :: n_env] ]
;
  
value update_conf_create conf =
  let field =
    match p_getenv conf.env "field" with
    [ Some f -> f ^ "_"
    | _ -> "" ]
  in
  let occ =
    match p_getenv conf.env "free_occ" with
    [ Some occ -> occ
    | _ -> "" ]
  in
  {(conf) with env = update_conf_env field "create" occ conf.env []}
;

value update_conf_link conf =
  let field =
    match p_getenv conf.env "field" with
    [ Some f -> f ^ "_"
    | _ -> "" ]
  in
  let occ =
    match p_getenv conf.env "link_occ" with
    [ Some occ -> occ
    | _ -> "" ]
  in
  {(conf) with env = update_conf_env field "link" occ conf.env []}
;

value update_conf conf =
  match p_getenv conf.env "link" with
  [ Some _ -> update_conf_link conf
  | None ->
      match p_getenv conf.env "create" with
      [ Some _ -> update_conf_create conf
      | None -> conf ] ]
;
