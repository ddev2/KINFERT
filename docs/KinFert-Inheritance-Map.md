# Reading the inheritance part of KinFert, in plain words

**30 September 2026.** Written to be read before the code, and written so that it still makes
sense when the details have gone cold. The technical details are in the last section, so that the
rest can be read straight through. Section 5 records the rules of succession as you stated them on
29 September; faults 1, 2 and 3 of section 6 were repaired on 30 September, with the division of the
ascendant shares. Fault 4, the country switch, is the only one left and it waits on one sentence
from you.

## 1. The two questions

Everything in this part of the program is there to answer two questions about a simulated person. Take Ana as
that person.

**Question A, who inherits from Ana.** Ana dies. Of all the relatives the program has simulated
around her, which ones inherit, and what share does each of them take?

**Question B, what Ana receives.** Ana's relatives die, one after another, over her life. For each
of those deaths, is Ana an heir, and if she is, what share does she receive?

The two questions look like mirror images and they are not, because Ana's kin network is built
around Ana. The program knows Ana's whole family, but it does not know the whole family of Ana's
cousin, so the answers it can give about Ana are better than the answers it can give about anyone
else.

## 2. Who answers each question

Years ago you wrote one method. Later you wrote a second one, and you left both of them running,
with a third piece of code to compare their answers. There are therefore two answers and a
comparison for each question. I will call the comparison the referee.

| | Question A, who inherits from Ana | Question B, what Ana receives |
|---|---|---|
| **First method** | Tries six possibilities in a fixed order: the children and their descendants, then the ascendants, then the partner, then the brothers and sisters and their descendants, then the aunts and uncles, then the great-aunts and great-uncles. It stops at the first one that answers yes, and what it writes down is mostly the **name of the branch** that inherits, with a list of people beside it | Goes through Ana's relatives one by one and works out, for each of them, whether Ana is an heir, how close a relative she is, and what fraction she takes. This is a separate piece of reasoning, about a hundred lines longer than everything else in the module |
| **Second method** | Searches four families in order of precedence, the descendants, the ascendants, the brothers and sisters with their descendants, and the wider collaterals, and writes down an **actual list of heirs with a share for each** | Nothing of its own. Every time it records an heir it also writes the mirror entry: "this person inherits from that one". So its answer to B is its answer to A, turned round |
| **Referee** | Compares the branch name and list of the first method with the list of the second | Compares the two lists of "who Ana inherits from" |

So yes, the referee you remembered is the one for question A, and there are indeed two methods
there. And yes, question B has a referee too. But question B's check is weaker than it looks, for
the reason in the next section.

## 3. Why the check on question B is weaker

For question A, the two methods really are two different searches. If they agree, that means
something.

For question B, only the first method does its own reasoning. The second method's answer is the
mirror of its own question A search, written at the same moment. So if that search is wrong, its
answer to B is wrong in exactly the same way, and the referee cannot see it. What the referee for
B actually compares is the first method's reasoning about Ana against the second method's heir
search read backwards. That is still worth having, since the two arrive by different routes, but
it is not two independent opinions.

## 4. The one thing that makes both referees complain for the wrong reason

The two methods do not cover the same people. The first method's question B goes through every
relative in Ana's network. The second method looks only at Ana herself and at the kin types listed
in one dialog setting. So the second method's lists are often shorter, and the referee then reports
a disagreement that is nothing but a difference of scope.

Anyone who trusts the referees before this is settled will spend days chasing differences that are
not errors. **Done for the referee of question A**, on 30 September, by the first of the two
remedies: that referee now says nothing at all about a relative that only one of the two methods
looked at. The referee of question B still has the problem.

## 5. The rules of succession, as you stated them

Recorded here because they are what the code has to follow, and because the faults below cannot be
repaired without them. Your words, 29 September.

- **Descendants inherit by lineage, not by head.** A woman leaves two children. One of them is dead
  but left two children of her own. The living child takes one half, and the two grandchildren take
  one quarter each, which is their dead parent's half divided between them. The estate is divided
  into as many parts as there are lines of descent, and a line whose head is dead is represented by
  that head's own descendants. The second search already does this, and it was checked on exactly
  that example.
- **Ascendants and lateral kin are excluded by degree.** The nearest degree takes everything and
  the rest take nothing. A surviving grandmother excludes every great-grandparent.
- **An ascendant estate is halved between the two sides of the family, and divided equally within
  a side.** The father's side and the mother's side take one half each, and the heirs of a side
  share that half in equal parts. A side with no heir at that degree leaves its half to the other
  side. Your two examples, 30 September: with three of the four grandparents alive, the two on one
  side take a quarter each and the one on the other side takes a half; with seven of the eight
  great-grandparents alive, the four on one side take an eighth each and the three on the other
  take a sixth each. The two lines within a side, the father's father's line and the father's
  mother's line, are not distinguished, and there is no further halving at each generation.
  `allocateShareAscendantsHeirs_2` was rewritten to this rule on 30 September; it used to give
  each line of descent an equal part, which differs only when the two sides hold a different
  number of surviving lines.
- **Lateral kin of the nearest degree take equal shares**, and at degree 4 that equality is
  deliberate: first cousins, grand-nieces and grand-nephews, and grand-aunts and grand-uncles are
  all of degree 4 and share equally. Aunts and uncles, of degree 3, exclude all of them. The second
  search already does this, in `Colaterals_2`.

**The choice of the heirs is by degree alone, and the division of the shares is by side.** Those
are two separate rules and it is worth keeping them apart: if one grandparent is alive and three
great-grandparents are alive, the estate goes to that one grandparent and to nobody else, whatever
side anybody is on. The descendants are the exception to all of this, dividing by line of descent
with representation, as the first rule above says.

Still not settled: whether a posthumous child is an heir, what becomes of an estate with no heir at
all, and whether usufruct is modelled. None of it blocks the work below.

## 6. The four faults

**Fault 1, in question A.** A man dies with no children and no partner. One grandmother is alive,
and so is a great-grandfather on the other side of the family. The law, and your own note at the
top of the file, say the nearest generation takes everything, so the grandmother should receive the
whole estate. The second method searches the father's side and the mother's side separately and
never compares what the two searches found, so both people are admitted and the grandmother
received half instead of all, and every share in an estate of that shape came out too small.
**Fixed on 30 September**, with the rules of section 5. The ascendants are explored one generation
at a time and the first generation that holds an heir is the only one that inherits:
`AscendantHeirs_2` asks for one generation at a time and keeps the first that answers, and the
search itself is untouched. The division of the shares was rewritten at the same time, to the rule
you stated: the estate is halved between the two sides of the family and divided equally within a
side, where it used to give each line of descent an equal part. That second part is `N22b` in the
TODO, and it is done. **Both change results.**

**Fault 2, in question B. Fixed on 30 September**, and `docs/KinFert-FIXED.md` has the detail. A
niece died with no descendant and no living parent or grandparent, so her aunts and uncles
inherited, and the program collected them from ego's side of the family. It asked the right
question first, which of ego's parents is a grandparent of the niece, and then threw the answer
away and collected the children of both of ego's parents. If ego and the niece's father shared only
their father, ego's mother was no relation of the niece, and her children by another man took an
equal share of the niece's estate. The answer is now used, as the first cousins block of the same
routine always used it. **This one changes results.**

Two of the five places that ask the question were the faulty ones. At two others the answer is not
needed, because they collect the children of the dead relative's own parents, and every one of
those shares a parent with the dead relative and is a blood sibling of it. Those two assigned the
answer and never read it, which is what made the fault hard to see, and the useless assignments are
gone.

**Fault 3, the referee for question A. Fixed on 30 September**, and `docs/KinFert-FIXED.md` has the
detail. It used to report agreement in the one case that is plainly a disagreement, when the first
method found nobody and the second found heirs; it reported disagreement when both found the same
people in a different order; one of its branches could never be reached; it could not express a
person who leaves both children and a surviving partner who inherits, because the first method
names one branch and the partner is one of the branches; and it read the difference of coverage of
section 4 as a disagreement. All five are dealt with, and each kind of disagreement it can now find
is a check with a name of its own in `verification.txt`. The referee for question B still compares
the two lists by position.

**Fault 4, the country switch.** The choice between the Spanish rules and the other rules is
offered in the dialog, is written to the configuration file and is read back from it, and nothing
anywhere consults its value. Both methods always run. There is also an empty routine that the
kinship module calls and that does nothing, which was meant to be the second method's answer to
question B before that answer came for free. What to do about it needs one sentence from you: is
that switch meant to choose between rule sets, or is it a leftover to remove? That is Q4.

## 7. What I would do, in order

1. **The two referees, and the coverage problem of section 4.** Half done: the referee for
   question A, which is fault 3, was fixed on 30 September, together with the coverage problem on
   its side. This changed no simulated number at all. What is left is the referee for question B,
   which still compares its two lists by position, and the coverage problem on that side. Review
   the part that is done before going further, since it is the instrument for everything else.
2. **Fault 2, the half-brother. Done on 30 September**, after the referee of question A, which is
   the order this list asked for. It changes shares, and the existing check that an estate's shares
   add up to one is how to see that it worked.
3. **Fault 1, the grandmother. Done on 30 September**, together with the division of the shares
   between the two sides of the family, `N22b`. It is the change to review most carefully, since it
   is the only one of the four that changes simulated results.
4. **Fault 4, the country switch**, once you have said what it is for.

## 8. Why not write a fresh version to check the old one

You already have two versions of question A, and the referee exists precisely to play them against
each other. Repairing the referee is a much smaller job than writing a third version, and it turns
the pair you have into a working check. The only place where new code earns its keep is the
coverage problem of section 4: having the second method look at every relative rather than only at
Ana. That is not a new method, it is the same one applied more widely, and it is part of item 1.

## 9. Where to look in the file

For the review you want to make. About seven hundred lines in all, in this order.

| what to read | where | why this one |
|---|---|---|
| `checkTreeForHeirs_2` | `inheritance.pas:2098` | The clearest statement in the whole program of what the model believes about succession: four families, in order of precedence. Start here |
| `exploreAscendantHeirsTree_2` and `allocateShareAscendantsHeirs_2` | `1537` and `1626` | The ascendant search of the second method, where fault 1 was, and the division of the shares, rewritten on 30 September to the rule of section 5, with `sideOfAscendantHeir` at `1602` above it. Read `AscendantHeirs_2` at `1660` with them: it is the routine the repair of fault 1 changed |
| `lookForHeirs` and the six tests it calls | `385`, then `148`, `184`, `267`, `277`, `350`, `363` | The first method's answer to question A. Short, and it shows why the referee compares a branch name against a list. The line that fills `partnerCanInherit` is at the top of its loop, and the two partner tests it uses are at `237` and `254` |
| `checkEgoIsHeir` | `786` to `1177` | The first method's answer to question B, and the longest routine of the module. The repair of fault 2 is at `947` and `996`, the model it follows at `1091`, and the two blocks that need no filter at `1058` and `1148`. Read it with `getSiblings` at `708` and `commonAncestor` at `775` beside it |
| `addHeir_2` and `addDecedent_2` | `1374` and `1322` | How the second method answers question B for free, by writing the mirror entry, which is the point of section 3 |
| `checkHeirs` and `checkInheritances` | `2337` and `2242` | The two referees. The first is the one repaired on 30 September, with `kinSetOfBranch` at `2267` and `heirsConfirmed` at `2296` above it; the second still compares by position |
| `lookForDecedents_Spain` | `2225` | The empty routine of fault 4 |

The four entry points are called one after another in `Kinship.pas:7164`, which is worth a look
first: two lines for the first method, two for the second.

The four faults are N22, N24, N26 and N25 in `docs/KinFert-TODO.md`: fault 1 is N22, fault 2 is
N24, fault 3 is N26 and fault 4 is N25. N22, N22b, N24 and N26 are fixed. N25 is the only one
left, it changes no simulated number, and it waits on your answer to Q4.

**Line numbers.** Those above are of 30 September, after the N26 change. `tools/check-line-numbers.py`
prints the current ones after any edit.
