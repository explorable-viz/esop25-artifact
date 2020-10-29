module Parse where

import Prelude hiding (absurd, add, between, join)
import Control.Alt ((<|>))
import Control.Apply (lift2)
import Control.Lazy (fix)
import Control.MonadPlus (empty)
import Data.Array (elem, fromFoldable)
import Data.Bitraversable (bisequence)
import Data.Either (choose)
import Data.Function (on)
import Data.Identity (Identity)
import Data.List (List(..), (:), concat, foldr, groupBy, reverse, singleton, snoc, sortBy)
import Data.List.NonEmpty (NonEmptyList(..), head, toList)
import Data.Map (values)
import Data.NonEmpty ((:|))
import Data.Ordering (invert)
import Data.Profunctor.Choice ((|||))
import Data.Tuple (fst, snd)
import Text.Parsing.Parser.Combinators (try)
import Text.Parsing.Parser.Expr (Operator(..), OperatorTable, buildExprParser)
import Text.Parsing.Parser.Language (emptyDef)
import Text.Parsing.Parser.String (char, eof, oneOf)
import Text.Parsing.Parser.Token (
  GenLanguageDef(..), LanguageDef, TokenParser, alphaNum, letter, makeTokenParser, unGenLanguageDef
)
import Bindings (Binding, (↦), fromList)
import DataType (Ctr(..), cPair, isCtrName, isCtrOp)
import Desugar (Branch, Clause)
import Desugar (Expr(..), Pattern(..), RawExpr(..), RecDefs, VarDef, VarDefs, expr) as S
import Expr (Elim, Expr(..), Module(..), RawExpr(..), RecDefs, Var, VarDef(..), VarDefs, expr)
import Lattice (𝔹)
import Pattern (Pattern(..), PCont(..), joinAll, setCont, toElim)
import Primitive (opDefs)
import Util (Endo, type (×), (×), type (+), error, onlyIf, successful, successfulWith)
import Util.Parse (SParser, sepBy_try, sepBy1, sepBy1_try, some)

-- constants (should also be used by prettyprinter)
strArrow       = "->"      :: String
strAs          = "as"      :: String
strBackslash   = "\\"      :: String
strEquals      = "="       :: String
strFun         = "fun"     :: String
strIn          = "in"      :: String
strLet         = "let"     :: String
strMatch       = "match"   :: String

languageDef :: LanguageDef
languageDef = LanguageDef (unGenLanguageDef emptyDef) {
   commentStart = "{-",
   commentEnd = "-}",
   commentLine = "--",
   nestedComments = true,
   identStart = letter <|> char '_',
   identLetter = alphaNum <|> oneOf ['_', '\''],
   opStart = opChar,
   opLetter = opChar,
   reservedOpNames = [],
   reservedNames = [strAs, strFun, strIn, strLet, strMatch],
   caseSensitive = true
} where
   opChar :: SParser Char
   opChar = oneOf [
      ':', '!', '#', '$', '%', '&', '*', '+', '.', '/', '<', '=', '>', '?', '@', '\\', '^', '|', '-', '~'
   ]

token :: TokenParser
token = makeTokenParser languageDef

-- 'reserved' parser only checks that str isn't a prefix of a valid identifier, not that it's in reservedNames.
keyword ∷ String → SParser Unit
keyword str =
   if str `elem` (unGenLanguageDef languageDef).reservedNames
   then token.reserved str
   else error $ str <> " is not a reserved word"

ident ∷ SParser Var
ident = do
   x <- token.identifier
   onlyIf (not $ isCtrName x) x

ctr :: SParser Ctr
ctr = do
   x <- token.identifier
   onlyIf (isCtrName x) $ Ctr x

-- Singleton eliminator with no continuation.
simplePattern :: Endo (SParser Pattern)
simplePattern pattern' =
   try ctr_pattern <|>
   try patternVariable <|>
   try (token.parens pattern') <|>
   patternPair

   where
   -- Constructor name as a nullary constructor pattern.
   ctr_pattern :: SParser Pattern
   ctr_pattern = PattConstr <$> ctr <@> 0 <@> PNone

   -- TODO: anonymous variables
   patternVariable :: SParser Pattern
   patternVariable = PattVar <$> ident <@> PNone

   patternPair :: SParser Pattern
   patternPair =
      token.parens $ do
         π <- pattern' <* token.comma
         π' <- pattern'
         pure $ PattConstr cPair 2 $ PArg $ setCont (PArg π') π

simplePattern2 :: Endo (SParser S.Pattern)
simplePattern2 pattern' =
   try ctr_pattern <|>
   try var_pattern <|>
   try (token.parens pattern') <|>
   pair_pattern

   where
   -- Constructor name as a nullary constructor pattern.
   ctr_pattern :: SParser S.Pattern
   ctr_pattern = S.PConstr <$> ctr <@> Nil

   -- TODO: anonymous variables
   var_pattern :: SParser S.Pattern
   var_pattern = S.PVar <$> ident

   pair_pattern :: SParser S.Pattern
   pair_pattern =
      token.parens $ do
         π <- pattern' <* token.comma
         π' <- pattern'
         pure $ S.PConstr cPair (π : π' : Nil)

arrow :: SParser Unit
arrow = token.reservedOp strArrow

equals :: SParser Unit
equals = token.reservedOp strEquals

patternDelim :: SParser Unit
patternDelim = arrow <|> equals

-- "curried" controls whether nested functions are permitted in this context
elim :: Boolean -> SParser (Expr 𝔹) -> SParser (Elim 𝔹)
elim curried expr' =
   successfulWith "Incompatible branches in match or lambda" <$> (joinAll <$> patterns)
   where
   patterns :: SParser (NonEmptyList Pattern)
   patterns = pure <$> patternOne curried expr' patternDelim <|> patternMany
      where
      patternMany :: SParser (NonEmptyList Pattern)
      patternMany = token.braces $ sepBy1 (patternOne curried expr' arrow) token.semi

patternOne :: Boolean -> SParser (Expr 𝔹) -> SParser Unit -> SParser Pattern
patternOne curried expr' delim = pattern' >>= rest
   where
   rest :: Pattern -> SParser Pattern
   rest π = setCont <$> body' <@> π
      where
      body' = if curried then body <|> PLambda <$> (pattern' >>= rest) else body

   pattern' = if curried then simplePattern pattern else pattern
   body = PBody <$> (delim *> expr')

branch :: Boolean -> SParser (S.Expr 𝔹) -> SParser Unit -> SParser (Branch 𝔹)
branch curried expr' delim = do
   πs <- if curried
         then some $ simplePattern2 pattern2
         else NonEmptyList <$> pattern2 `lift2 (:|)` pure Nil
   e <- delim *> expr'
   pure $ πs × e

branches :: Boolean -> SParser (S.Expr 𝔹) -> SParser (NonEmptyList (Branch 𝔹))
branches curried expr' =
   pure <$> branch curried expr' patternDelim <|> branchMany
   where
   branchMany :: SParser (NonEmptyList (Branch 𝔹))
   branchMany = token.braces $ sepBy1 (branch curried expr' arrow) token.semi

varDefs :: SParser (Expr 𝔹) -> SParser (VarDefs 𝔹)
varDefs expr' = keyword strLet *> sepBy1_try clause token.semi <#> toList
   where
   clause :: SParser (VarDef 𝔹)
   clause = VarDef <$> (successful <<< toElim <$> pattern <* patternDelim) <*> expr'

varDefs2 :: SParser (S.Expr 𝔹) -> SParser (S.VarDefs 𝔹)
varDefs2 expr' = keyword strLet *> sepBy1_try clause token.semi <#> toList
   where
   clause :: SParser (S.VarDef 𝔹)
   clause = (pattern2 <* patternDelim) `lift2 (×)` expr'

recDefs :: SParser (Expr 𝔹) -> SParser (RecDefs 𝔹)
recDefs expr' = do
   fπs <- keyword strLet *> sepBy1_try clause token.semi <#> toList
   let fπss = groupBy (eq `on` fst) fπs
   pure $ fromList $ reverse $ toRecDef <$> fπss
   where
   toRecDef :: NonEmptyList (Var × Pattern) -> Binding Elim 𝔹
   toRecDef fπs =
      let f = fst $ head fπs in
      f ↦ successfulWith ("Bad branches for '" <> f <> "'") (joinAll $ snd <$> fπs)

   clause :: SParser (Var × Pattern)
   clause = ident `lift2 (×)` (patternOne true expr' equals)

recDefs2 :: SParser (S.Expr 𝔹) -> SParser (S.RecDefs 𝔹)
recDefs2 expr' = do
   keyword strLet *> sepBy1_try clause token.semi
   where
   clause :: SParser (Clause 𝔹)
   clause = ident `lift2 (×)` (branch true expr' equals)

defs :: SParser (Expr 𝔹) -> SParser (List (VarDef 𝔹 + RecDefs 𝔹))
defs expr' = bisequence <$> choose (try $ varDefs expr') (singleton <$> recDefs expr')

defs2 :: SParser (S.Expr 𝔹) -> SParser (List (S.VarDef 𝔹 + S.RecDefs 𝔹))
defs2 expr' = bisequence <$> choose (try $ varDefs2 expr') (singleton <$> recDefs2 expr')

-- Tree whose branches are binary primitives and whose leaves are application chains.
expr_ :: SParser (Expr 𝔹)
expr_ = fix $ appChain >>> buildExprParser (operators binaryOp)
   where
   -- Syntactically distinguishing infix constructors from other operators (a la Haskell) allows us to
   -- optimise an application tree into a (potentially partial) constructor application.
   binaryOp :: String -> SParser (Expr 𝔹 -> Expr 𝔹 -> Expr 𝔹)
   binaryOp op = do
      op' <- token.operator
      onlyIf (op == op') $
         if isCtrOp op'
         then \e e' -> expr $ Constr (Ctr op') (e : e' : empty)
         else \e e' -> expr $ BinaryApp e op e'

   -- Left-associative tree of applications of one or more simple terms.
   appChain :: Endo (SParser (Expr 𝔹))
   appChain expr' = simpleExpr >>= rest
      where
      rest :: Expr 𝔹 -> SParser (Expr 𝔹)
      rest e@(Expr _ (Constr c es)) = ctrArgs <|> pure e
         where
         ctrArgs :: SParser (Expr 𝔹)
         ctrArgs = simpleExpr >>= \e' -> rest (expr $ Constr c (es <> (e' : empty)))
      rest e = (expr <$> (App e <$> simpleExpr) >>= rest) <|> pure e

      -- Any expression other than an operator tree or an application chain.
      simpleExpr :: SParser (Expr 𝔹)
      simpleExpr =
         try ctrExpr <|>
         try variable <|>
         try float <|>
         try int <|> -- int may start with +/-
         string <|>
         defsExpr <|>
         matchAs <|>
         try (token.parens expr') <|>
         try parensOp <|>
         pair <|>
         lambda

         where
         ctrExpr :: SParser (Expr 𝔹)
         ctrExpr = expr <$> (Constr <$> ctr <@> empty)

         variable :: SParser (Expr 𝔹)
         variable = ident <#> Var >>> expr

         signOpt :: ∀ a . Ring a => SParser (a -> a)
         signOpt = (char '-' $> negate) <|> (char '+' $> identity) <|> pure identity

         -- built-in integer/float parsers don't seem to allow leading signs.
         int :: SParser (Expr 𝔹)
         int = do
            sign <- signOpt
            (sign >>> Int >>> expr) <$> token.natural

         float :: SParser (Expr 𝔹)
         float = do
            sign <- signOpt
            (sign >>> Float >>> expr) <$> token.float

         string :: SParser (Expr 𝔹)
         string = (Str >>> expr) <$> token.stringLiteral

         defsExpr :: SParser (Expr 𝔹)
         defsExpr = do
            defs' <- concat <<< toList <$> sepBy1 (defs expr') token.semi
            foldr (\def -> expr <<< (Let ||| LetRec) def) <$> (keyword strIn *> expr') <@> defs'

         matchAs :: SParser (Expr 𝔹)
         matchAs = expr <$> (MatchAs <$> (keyword strMatch *> expr' <* keyword strAs) <*> elim false expr')

         -- any binary operator, in parentheses
         parensOp :: SParser (Expr 𝔹)
         parensOp = expr <$> (Op <$> token.parens token.operator)

         pair :: SParser (Expr 𝔹)
         pair = token.parens $
            expr <$> (lift2 $ \e e' -> Constr cPair (e : e' : empty)) (expr' <* token.comma) expr'

         lambda :: SParser (Expr 𝔹)
         lambda = expr <$> (Lambda <$> (keyword strFun *> elim true expr'))

-- Tree whose branches are binary primitives and whose leaves are application chains.
expr2 :: SParser (S.Expr 𝔹)
expr2 = fix $ appChain >>> buildExprParser (operators binaryOp)
   where
   -- Syntactically distinguishing infix constructors from other operators (a la Haskell) allows us to
   -- optimise an application tree into a (potentially partial) constructor application.
   binaryOp :: String -> SParser (S.Expr 𝔹 -> S.Expr 𝔹 -> S.Expr 𝔹)
   binaryOp op = do
      op' <- token.operator
      onlyIf (op == op') $
         if isCtrOp op'
         then \e e' -> S.expr $ S.Constr (Ctr op') (e : e' : empty)
         else \e e' -> S.expr $ S.BinaryApp e op e'

   -- Left-associative tree of applications of one or more simple terms.
   appChain :: Endo (SParser (S.Expr 𝔹))
   appChain expr' = simpleExpr >>= rest
      where
      rest :: S.Expr 𝔹 -> SParser (S.Expr 𝔹)
      rest e@(S.Expr _ (S.Constr c es)) = ctrArgs <|> pure e
         where
         ctrArgs :: SParser (S.Expr 𝔹)
         ctrArgs = simpleExpr >>= \e' -> rest (S.expr $ S.Constr c (es <> (e' : empty)))
      rest e = (S.expr <$> (S.App e <$> simpleExpr) >>= rest) <|> pure e

      -- Any expression other than an operator tree or an application chain.
      simpleExpr :: SParser (S.Expr 𝔹)
      simpleExpr =
         try ctrExpr <|>
         try variable <|>
         try float <|>
         try int <|> -- int may start with +/-
         string <|>
         defsExpr <|>
         matchAs <|>
         try (token.parens expr') <|>
         try parensOp <|>
         pair <|>
         lambda

         where
         ctrExpr :: SParser (S.Expr 𝔹)
         ctrExpr = S.expr <$> (S.Constr <$> ctr <@> empty)

         variable :: SParser (S.Expr 𝔹)
         variable = ident <#> S.Var >>> S.expr

         signOpt :: ∀ a . Ring a => SParser (a -> a)
         signOpt = (char '-' $> negate) <|> (char '+' $> identity) <|> pure identity

         -- built-in integer/float parsers don't seem to allow leading signs.
         int :: SParser (S.Expr 𝔹)
         int = do
            sign <- signOpt
            (sign >>> S.Int >>> S.expr) <$> token.natural

         float :: SParser (S.Expr 𝔹)
         float = do
            sign <- signOpt
            (sign >>> S.Float >>> S.expr) <$> token.float

         string :: SParser (S.Expr 𝔹)
         string = (S.Str >>> S.expr) <$> token.stringLiteral

         defsExpr :: SParser (S.Expr 𝔹)
         defsExpr = do
            defs' <- concat <<< toList <$> sepBy1 (defs2 expr') token.semi
            foldr (\def -> S.expr <<< (S.Let ||| S.LetRec) def) <$> (keyword strIn *> expr') <@> defs'

         matchAs :: SParser (S.Expr 𝔹)
         matchAs = S.expr <$> (S.MatchAs <$> (keyword strMatch *> expr' <* keyword strAs) <*> branches false expr')

         -- any binary operator, in parentheses
         parensOp :: SParser (S.Expr 𝔹)
         parensOp = S.expr <$> (S.Op <$> token.parens token.operator)

         pair :: SParser (S.Expr 𝔹)
         pair = token.parens $
            S.expr <$> (lift2 $ \e e' -> S.Constr cPair (e : e' : empty)) (expr' <* token.comma) expr'

         lambda :: SParser (S.Expr 𝔹)
         lambda = S.expr <$> (S.Lambda <$> (keyword strFun *> branches true expr'))

-- each element of the top-level list corresponds to a precedence level
operators :: forall a . (String -> SParser (a -> a -> a)) -> OperatorTable Identity String a
operators binaryOp =
   fromFoldable $ fromFoldable <$>
   (map (\({ op, assoc }) -> Infix (try $ binaryOp op) assoc)) <$>
   groupBy (eq `on` _.prec) (sortBy (\x -> comparing _.prec x >>> invert) $ values opDefs)

-- Pattern with no continuation.
pattern :: SParser Pattern
pattern = fix $ appChain_pattern >>> buildExprParser (operators infixCtr)
   where
   -- Analogous in some way to app_chain, but nothing higher-order here: no explicit application nodes,
   -- non-saturated constructor applications, or patterns other than constructors in the function position.
   appChain_pattern :: Endo (SParser Pattern)
   appChain_pattern pattern' = simplePattern pattern' >>= rest
      where
         rest ∷ Pattern -> SParser Pattern
         rest π@(PattConstr c n κ) = ctrArgs <|> pure π
            where
            ctrArgs :: SParser Pattern
            ctrArgs = simplePattern pattern' >>= \π' -> rest $ setCont (PArg π') $ PattConstr c (n + 1) κ
         rest π@(PattVar _ _) = pure π

   infixCtr :: String -> SParser (Pattern -> Pattern -> Pattern)
   infixCtr op = do
      op' <- token.operator
      onlyIf (isCtrOp op' && op == op') \π π' -> PattConstr (Ctr op') 2 $ PArg $ setCont (PArg π') π

-- Pattern with no continuation.
pattern2 :: SParser S.Pattern
pattern2 = fix $ appChain_pattern >>> buildExprParser (operators infixCtr)
   where
   -- Analogous in some way to app_chain, but nothing higher-order here: no explicit application nodes,
   -- non-saturated constructor applications, or patterns other than constructors in the function position.
   appChain_pattern :: Endo (SParser S.Pattern)
   appChain_pattern pattern' = simplePattern2 pattern' >>= rest
      where
         rest ∷ S.Pattern -> SParser S.Pattern
         rest π@(S.PConstr c πs) = ctrArgs <|> pure π
            where
            ctrArgs :: SParser S.Pattern
            ctrArgs = simplePattern2 pattern' >>= \π' -> rest $ S.PConstr c (πs `snoc` π')
         rest π@(S.PVar _) = pure π

   infixCtr :: String -> SParser (S.Pattern -> S.Pattern -> S.Pattern)
   infixCtr op = do
      op' <- token.operator
      onlyIf (isCtrOp op' && op == op') \π π' -> S.PConstr (Ctr op') (π' : π : Nil)

topLevel :: forall a . Endo (SParser a)
topLevel p = token.whiteSpace *> p <* eof

program ∷ SParser (Expr 𝔹)
program = topLevel expr_

program2 ∷ SParser (S.Expr 𝔹)
program2 = topLevel expr2

module_ :: SParser (Module 𝔹)
module_ = Module <<< concat <$> topLevel (sepBy_try (defs expr_) token.semi <* token.semi)
