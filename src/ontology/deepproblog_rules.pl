% SPDX-License-Identifier: PMPL-1.0-or-later
% deepproblog_rules.pl — Probabilistic logic rules for statistical reasoning.
%
% DeepProbLog extends Prolog with neural predicates and probabilistic facts.
% This file defines the probabilistic logic layer that gives Aspasia its
% neurosymbolic reasoning capability.
%
% WHY DEEPPROBLOG AND NOT JUST PROLOG?
% ────────────────────────────────────
% Pure Prolog gives us crisp yes/no answers: "this test is appropriate" or
% "this test is not appropriate." But statistical reasoning often involves
% degrees of confidence: "this test is PROBABLY appropriate, but check X."
%
% DeepProbLog lets us express probabilistic rules:
%   0.85::appropriate(t_test, Data) :- normal(Data), n_sufficient(Data).
%   0.60::appropriate(t_test, Data) :- roughly_normal(Data), n_large(Data).
%
% This is genuinely neurosymbolic — the probabilities can be learned from
% data (the neural part) while the logical structure is fixed (the symbolic
% part). The result is auditable probabilistic reasoning, not black-box
% neural prediction.

%% ═══════════════════════════════════════════════════════════════
%% PROBABILISTIC APPROPRIATENESS RULES
%% ═══════════════════════════════════════════════════════════════

% High confidence: all assumptions met
0.95::test_confidence(t_test_independent, high) :-
    data_normal(group1),
    data_normal(group2),
    variance_homogeneous,
    n_per_group(N), N >= 30.

% Medium confidence: robust to violations with large N
0.75::test_confidence(t_test_independent, medium) :-
    roughly_symmetric(group1),
    roughly_symmetric(group2),
    n_per_group(N), N >= 30.

% Low confidence: assumptions violated but test requested
0.30::test_confidence(t_test_independent, low) :-
    \+ data_normal(group1),
    n_per_group(N), N < 15.

% Recommendation strength
0.90::recommend(nonparametric) :-
    test_confidence(t_test_independent, low).

0.85::recommend(transform_data) :-
    skewed(data),
    all_positive(data).


%% ═══════════════════════════════════════════════════════════════
%% ROBUSTNESS ASSESSMENT
%% ═══════════════════════════════════════════════════════════════

% The t-test is robust to normality violations when:
0.90::robust_to_violation(t_test_independent, normality) :-
    n_per_group(N), N >= 30,
    skewness(S), abs(S) < 2.0.

% The t-test is NOT robust when:
0.10::robust_to_violation(t_test_independent, normality) :-
    n_per_group(N), N < 15,
    skewness(S), abs(S) > 1.0.

% ANOVA is robust to unequal variances when group sizes are equal
0.85::robust_to_violation(one_way_anova, homogeneity) :-
    group_sizes_equal,
    largest_variance_ratio(R), R < 3.0.


%% ═══════════════════════════════════════════════════════════════
%% EXPLANATION CONFIDENCE
%% ═══════════════════════════════════════════════════════════════

% How confident are we that an LLM's explanation is correct?
% This is the core neurosymbolic audit question.

% High confidence if explanation matches ontological rules
0.95::explanation_valid(Explanation) :-
    test_named(Explanation, TestName),
    test_appropriate(TestName, DataScale, N),
    assumptions_checked(Explanation),
    effect_size_reported(Explanation).

% Medium confidence if test is appropriate but assumptions not mentioned
0.60::explanation_valid(Explanation) :-
    test_named(Explanation, TestName),
    test_appropriate(TestName, DataScale, N),
    \+ assumptions_checked(Explanation).

% Low confidence if test is inappropriate for the data
0.10::explanation_valid(Explanation) :-
    test_named(Explanation, TestName),
    test_inappropriate(TestName, DataScale, N, _Reason).

% Zero confidence if the explanation contains a known misinterpretation
0.01::explanation_valid(Explanation) :-
    contains_misinterpretation(Explanation, _Type).


%% ═══════════════════════════════════════════════════════════════
%% CHALLENGE GENERATION
%% ═══════════════════════════════════════════════════════════════

% Generate Socratic challenges based on probabilistic reasoning

challenge(why_this_test, TestName, DataScale) :-
    test_appropriate(TestName, DataScale, _),
    nonparametric_alternative(TestName, Alt),
    format(atom(Question),
           'You chose ~w. What evidence supports the parametric assumptions? ~w would not require these assumptions.',
           [TestName, Alt]).

challenge(sample_size_concern, TestName, N) :-
    test(TestName, _, _, MinN, _),
    N < MinN * 2,  % Less than double the minimum
    format(atom(Question),
           'n=~w meets the minimum for ~w, but power may be low. Did you consider a power analysis?',
           [N, TestName]).

challenge(effect_size_missing, TestName) :-
    test(TestName, Purpose, _, _, _),
    Purpose \== describe,
    format(atom(Question),
           'You reported significance for ~w but did not mention effect size. Statistical significance alone is insufficient — what is the practical magnitude?',
           [TestName]).

challenge(multiple_comparisons, NumTests) :-
    NumTests > 1,
    AdjustedAlpha is 0.05 / NumTests,
    format(atom(Question),
           'You ran ~w tests. Without correction, the family-wise error rate inflates. Bonferroni-adjusted alpha = ~f',
           [NumTests, AdjustedAlpha]).
