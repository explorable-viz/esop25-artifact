module Pretty (class Pretty, pretty, module P, (:<>:)) where

import Prelude hiding (absurd)
import Data.List (List(..), (:), head)
import Data.Map (Map, toUnfoldable)
import Data.String (Pattern(..), contains)
import Text.Pretty (Doc, atop, beside, hcat, render, text, vcat)
import Text.Pretty (render) as P
import Bindings (Bindings(..), Bind, (:+:), (↦), elem)
import DataType (Ctr, cPair, cCons)
import Expr (Cont(..), Elim(..), Expr(..), RawExpr, RecDef(..), VarDef(..))
import Expr (RawExpr(..)) as E
import Expl as T
import Expl (Expl, Match(..))
import Util (type (×), (×), absurd, error, fromJust, intersperse)
import Val (BinaryOp(..), Val(..), RawVal, UnaryOp(..))
import Val (RawVal(..)) as V
import Primitive (primitives)

infixl 5 beside as :<>:

brackets :: Doc -> Doc
brackets doc = text "[" :<>: doc :<>: text "]"

comma :: Doc
comma = text "," :<>: space

space :: Doc
space = text " "

tab :: Doc
tab = text "   "

operator :: String -> Doc
operator op = space :<>: text op :<>: space

parens :: Doc -> Doc
parens doc = text "(" :<>: doc :<>: text ")"

parens2 :: Doc -> Doc
parens2 doc = atop (text "(" :<>: doc)  (text ")")

cbrackets :: Doc -> Doc
cbrackets doc = text "{" :<>: doc :<>: text "}"

null :: Doc
null = text ""

class Pretty p where
   pretty :: p -> Doc

class PrettyList p where
   prettyList :: p -> Doc

instance boolPretty :: Pretty Boolean where
   pretty true = text "true"
   pretty false = text "false"

instance envPretty :: Pretty (Bindings Val) where
   pretty (ρ :+: x ↦ v) = brackets $ prettyList ρ :<>: (text x :<>: text " ↦ " :<>: pretty v)
   pretty Empty = text "[]"

instance explPretty :: Pretty Expl where
   pretty (T.Var x ρ) = text x
   pretty (T.Op op ρ) = text op
   pretty (T.Int n ρ) = text $ show n
   pretty (T.Str s) = text s
   pretty (T.Constr c es) = prettyConstr c es
   pretty (T.NullConstr c ρ) = pretty c
   pretty (T.Lambda σ) = text "fun " :<>: pretty σ
   pretty (T.App tv t' ξ t'') =  text "App" :<>: parens (atop (text "t1: " :<>: pretty tv :<>: comma) (atop (text "t2: " :<>: pretty t' :<>: comma) (atop (text "match: " :<>:  pretty ξ :<>: comma) (text "t3: " :<>: pretty t''))))
   pretty (T.AppOp tv tv') = pretty tv :<>: space :<>: pretty tv'
   pretty (T.BinaryApp tv op tv') = pretty tv :<>: space :<>: text op :<>: space :<>: pretty tv'
   pretty (T.MatchAs t ξ t') = atop (text "match " :<>: pretty t :<>: text " as {")
                                 (atop (tab :<>: pretty ξ) (atop (text "} where outcome was: ") (tab :<>: pretty t') ))
   pretty (T.Let (T.VarDef ξ t) t') = atop (text "let " :<>: pretty ξ :<>: text " = " :<>: pretty t :<>: text " in")
                                        (pretty t')
   pretty (T.LetRec δ t) = atop (text "letrec " :<>: pretty δ) (text "in     " :<>: pretty t)

instance explMatch :: Pretty Match where
   pretty (MatchConstr (ctr × ξs) ks) = text "ξ = " :<>: (atop (text "Pattern:       " :<>: pretty (ctr × ξs))
                                                               (text "Continuations: " :<>: pretty ks))
   pretty (MatchVar x) = text "ξ = " :<>: text x

instance explValPretty :: Pretty (Expl × Val) where
   pretty (a × b) = parens $ pretty a :<>: comma :<>: pretty b

instance envPrettyList :: PrettyList (Bindings Val) where
   prettyList (ρ :+: x ↦ Val α v)
      | x `elem` primitives = prettyList ρ :<>: (text x :<>: text " ↦ " :<>: pretty v) :<>: text ", "
      | otherwise           = prettyList ρ
   prettyList Empty = text ""

instance explPrettyList :: PrettyList Expl where
   prettyList (T.Constr cNil Nil) = null
   prettyList (T.NullConstr cNil ρ) = text "NilExpl"
   prettyList (T.Constr cCons (e:es:Nil)) = comma :<>: pretty e :<>: prettyList es
   prettyList t = error "Ill-formed list for expls"

instance exprPrettyList :: PrettyList Expr where
   prettyList (Expr a r) = text "Expr (" :<>: text (show a) :<>: comma :<>: prettyList r :<>: text ")"

instance rawExprPrettyList :: PrettyList RawExpr where
   prettyList (E.Constr cNil Nil) = null
   prettyList (E.Constr cCons (e:es:Nil)) = comma :<>: pretty e :<>: prettyList es
   prettyList e = error "Ill-formed list for exprs"

instance valPrettyList :: PrettyList Val where
   prettyList (Val _ u) = prettyList u

instance rawValPrettyList :: PrettyList RawVal where
   prettyList (V.Constr cNil Nil) = null
   prettyList (V.Constr cCons (v:vs:Nil)) = comma :<>: pretty v :<>: prettyList vs
   prettyList v = error "Ill-formed list for values"

instance exprPretty :: Pretty Expr where
   pretty (Expr _ r) = pretty r

instance prettyCtr :: Pretty Ctr where
   pretty = show >>> text

-- Cheap hack to make progress on migrating some tests; need to revisit.
prettyParensOpt :: forall a . Pretty a => a -> Doc
prettyParensOpt x =
   let doc = pretty x in
   if contains (Pattern " ") $ render doc
   then parens doc
   else doc

prettyConstr :: forall a . Pretty a => PrettyList a => Ctr -> List a -> Doc
prettyConstr c Nil = pretty c
prettyConstr c xs@(x : xs')
   | c == cPair   = parens $ pretty x :<>: comma :<>: pretty (fromJust absurd $ head xs')
   | c == cCons   = brackets $ pretty x :<>: prettyList (fromJust absurd $ head xs')
   | otherwise  = pretty c :<>: space :<>: hcat (intersperse space $ map prettyParensOpt xs)

instance rawExprPretty :: Pretty RawExpr where
   pretty (E.Int n) = text $ show n
   pretty (E.Str str) = text $ show str
   pretty (E.Var x) = text x
   pretty (E.Constr c es) = prettyConstr c es
   pretty (E.Op op) = parens $ text op
   pretty (E.Let (VarDef σ e) e') =
      atop (text ("let ") :<>: pretty σ :<>: operator "->" :<>: pretty e :<>: text " in") (pretty e')
   pretty (E.MatchAs e σ) = atop (atop (text "match " :<>: pretty e :<>: text " as {") (tab :<>: pretty σ)) (text "}")
   pretty (E.LetRec δ e) =
      atop (text "letrec " :<>: pretty δ) (text "in " :<>: pretty e)
   pretty (E.Lambda σ) = text "fun " :<>: pretty σ
   pretty (E.App e e') = pretty e :<>: space :<>: pretty e'
   pretty (E.BinaryApp e op e') = pretty e :<>: operator op :<>: pretty e'

instance prettylistExpl :: Pretty (List Expl) where
   pretty Nil    = text ""
   pretty (v:vs) = brackets (pretty v :<>: prettyList vs)

instance prettylistExplList :: PrettyList (List Expl) where
   prettyList Nil    = text ""
   prettyList (v:vs) = comma :<>: pretty v :<>: prettyList vs

instance prettylistExplVal :: Pretty (List (Expl × Val)) where
   pretty Nil    = text ""
   pretty (v:vs) = brackets (pretty v :<>: prettyList vs)

instance prettylistExplValList :: PrettyList (List (Expl × Val)) where
   prettyList Nil    = text ""
   prettyList (v:vs) = comma :<>: pretty v :<>: prettyList vs

instance prettyVEB :: Pretty (List ((Bindings Val) × (Expr × Boolean))) where
   pretty Nil    = text ""
   pretty ((v × e × b):vs) = brackets (parens (pretty v) :<>: prettyList vs)

instance prettyVEBList :: PrettyList (List ((Bindings Val) × (Expr × Boolean))) where
   prettyList Nil    = text ""
   prettyList ((v × e × b):vs) = comma :<>: (parens (pretty v) :<>: prettyList vs)


instance prettyDefs :: Pretty (List RecDef) where
   pretty Nil              = text ""
   pretty (RecDef f σ : δ) = atop (text f :<>: operator "=" :<>: pretty σ) $ pretty δ

instance prettyMatches :: Pretty (List Match) where
   pretty Nil    = text ""
   pretty (ξ:ξs) = atop (pretty ξ) $ pretty ξs

instance prettyValsList :: PrettyList (List Val) where
   prettyList Nil    = text ""
   prettyList (v:vs) = comma :<>: pretty v :<>: prettyList vs

instance prettyVals :: Pretty (List Val) where
   pretty Nil    = text ""
   pretty (v:vs) = brackets (pretty v :<>: prettyList vs)

instance prettyExprList :: PrettyList (List Expr) where
   prettyList Nil    = text ""
   prettyList (e:es) = comma :<>: pretty e :<>: prettyList es

instance prettyExpr :: Pretty (List Expr) where
   pretty Nil    = text ""
   pretty (e:es) = brackets (pretty e :<>: prettyList es)

instance prettyBranches :: Pretty (Map Ctr Cont) where
   pretty m = vcat $ map pretty $ (toUnfoldable m :: List _)

instance prettyBind :: Pretty a => Pretty (Bind a) where
   pretty (x ↦ v) = text x :<>: text " ↦ " :<>: pretty v

instance prettyCont :: Pretty Cont where
   pretty None          = text "[ ]"
   pretty (Body e)      = pretty e
   pretty (Arg σ)       = pretty σ

instance prettyBranch :: Pretty (Ctr × Cont) where
   pretty (c × κ) = text (show c) :<>: operator "->" :<>: pretty κ

instance prettyBranch2 :: Pretty (Ctr × List Match) where
   pretty (c × ξs) = text (show c) :<>: operator "-> " :<>: pretty ξs

instance prettyElim2 :: Pretty Elim where
   pretty (ElimVar x κ)    = text x :<>: operator "->" :<>: pretty κ
   pretty (ElimConstr κs)  = vcat $ map pretty $ (toUnfoldable κs :: List _)

instance valPretty :: Pretty Val where
   pretty (Val a u) = pretty u

instance rawValPretty :: Pretty RawVal where
   pretty (V.Int n)  = text $ show n
   pretty (V.Str str) = text $ show str
   pretty (V.Constr c vs) = prettyConstr c vs
   pretty (V.Closure ρ δ σ)
    = text "Closure" :<>: text "(" :<>:
    (atop (atop (text "env: " :<>: pretty ρ) (text "defs: " :<>: pretty δ)) (text "elim: " :<>: pretty σ)) :<>: (text ")")
   pretty (V.Unary op) = parens $ pretty op
   pretty (V.Binary op) = parens $ pretty op

instance unaryOpPretty :: Pretty UnaryOp where
   pretty (UnaryOp name _) = text name
   pretty (PartialApp φ v) = pretty φ :<>: text "-" :<>: pretty v

instance binaryOpPretty :: Pretty BinaryOp where
   pretty (BinaryOp name _) = text name

prettyProgram :: Expr -> Doc
prettyProgram e = atop (pretty e) (text "")
