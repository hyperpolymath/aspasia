% SPDX-License-Identifier: PMPL-1.0-or-later
% statistical_ontology.pl — Ontological backbone for statistical reasoning.
%
% WHY PROLOG?
% ──────────
% Statistical test selection is a LOGICAL problem, not a numerical one.
% "Can I use a t-test here?" is a question about preconditions, assumptions,
% and data properties — not about computation. Prolog is the natural language
% for expressing these relationships.
%
% This replaces what an LLM would otherwise hallucinate: "Sure, a t-test
% is appropriate here!" (when it might not be). Instead, we PROVE it.
%
% RELATIONSHIP TO OPENCYC
% ──────────────────────────
% OpenCyc provides the upper ontology (what IS a statistical test, what IS
% a data type). We extend it with domain-specific statistical knowledge.
% If OpenCyc is unavailable, these rules stand alone as a self-contained
% statistical ontology.

%% ═══════════════════════════════════════════════════════════════
%% DATA TYPE ONTOLOGY (Stevens' levels of measurement)
%% ═══════════════════════════════════════════════════════════════

% Scale hierarchy: nominal < ordinal < interval < ratio
scale_level(nominal, 0).
scale_level(ordinal, 1).
scale_level(interval, 2).
scale_level(ratio, 3).

% A test requiring level L can accept any level >= L
scale_sufficient(Required, Actual) :-
    scale_level(Required, R),
    scale_level(Actual, A),
    A >= R.

% Data properties
data_property(continuous).
data_property(discrete).
data_property(categorical).
data_property(binary).

% Relationships between properties and scales
scale_implies(ratio, continuous).
scale_implies(interval, continuous).
scale_implies(ordinal, discrete).
scale_implies(nominal, categorical).
binary_is(categorical).


%% ═══════════════════════════════════════════════════════════════
%% STATISTICAL TEST ONTOLOGY
%% ═══════════════════════════════════════════════════════════════

% test(Name, Purpose, MinScale, MinN, Assumptions)

test(descriptive_stats, describe, nominal, 1, []).

test(t_test_independent, compare_two_groups, interval, 5,
     [normality, homogeneity_of_variance, independence]).

test(t_test_paired, compare_paired, interval, 5,
     [normality_of_differences, paired_observations]).

test(t_test_one_sample, compare_to_value, interval, 5,
     [normality]).

test(one_way_anova, compare_multiple_groups, interval, 5,
     [normality, homogeneity_of_variance, independence]).

test(chi_square_test, test_association, nominal, 5,
     [expected_frequency_min_5, independence]).

test(chi_square_goodness, test_distribution, nominal, 5,
     [expected_frequency_min_5]).

test(pearson_correlation, measure_linear_association, interval, 10,
     [normality, linearity, homoscedasticity]).

test(spearman_correlation, measure_monotonic_association, ordinal, 10,
     [monotonic_relationship]).

test(simple_linear_regression, predict_continuous, interval, 20,
     [normality_of_residuals, linearity, homoscedasticity, independence]).

test(multiple_regression, predict_continuous_multiple, interval, 50,
     [normality_of_residuals, linearity, homoscedasticity,
      independence, no_multicollinearity]).

test(mann_whitney_u, compare_two_groups_nonparam, ordinal, 5, [independence]).

test(wilcoxon_signed_rank, compare_paired_nonparam, ordinal, 5,
     [symmetry_of_differences]).

test(kruskal_wallis, compare_multiple_groups_nonparam, ordinal, 5,
     [independence]).

test(cronbachs_alpha, measure_reliability, interval, 10,
     [unidimensionality]).

test(cohens_kappa, measure_agreement, nominal, 10, []).

test(bayes_factor, compare_hypotheses, interval, 10, []).


%% ═══════════════════════════════════════════════════════════════
%% TEST APPROPRIATENESS RULES
%% ═══════════════════════════════════════════════════════════════

% A test is appropriate if scale and sample size requirements are met
test_appropriate(TestName, DataScale, N) :-
    test(TestName, _, RequiredScale, MinN, _),
    scale_sufficient(RequiredScale, DataScale),
    N >= MinN.

% A test is inappropriate (and we can explain why)
test_inappropriate(TestName, DataScale, N, Reason) :-
    test(TestName, _, RequiredScale, _, _),
    \+ scale_sufficient(RequiredScale, DataScale),
    format(atom(Reason),
           'Scale violation: ~w requires ~w data but got ~w',
           [TestName, RequiredScale, DataScale]).

test_inappropriate(TestName, _, N, Reason) :-
    test(TestName, _, _, MinN, _),
    N < MinN,
    format(atom(Reason),
           'Sample size violation: ~w requires n >= ~w but got n = ~w',
           [TestName, MinN, N]).

% Assumption violations
assumption_violated(TestName, normality, SkewVal, KurtVal) :-
    test(TestName, _, _, _, Assumptions),
    member(normality, Assumptions),
    (abs(SkewVal) > 2.0 ; abs(KurtVal) > 7.0).

assumption_violated(TestName, homogeneity_of_variance, LeveneP) :-
    test(TestName, _, _, _, Assumptions),
    member(homogeneity_of_variance, Assumptions),
    LeveneP < 0.05.


%% ═══════════════════════════════════════════════════════════════
%% NONPARAMETRIC ALTERNATIVES
%% ═══════════════════════════════════════════════════════════════

% When assumptions are violated, suggest nonparametric alternatives
nonparametric_alternative(t_test_independent, mann_whitney_u).
nonparametric_alternative(t_test_paired, wilcoxon_signed_rank).
nonparametric_alternative(one_way_anova, kruskal_wallis).
nonparametric_alternative(pearson_correlation, spearman_correlation).

suggest_alternative(TestName, Alternative, Reason) :-
    nonparametric_alternative(TestName, Alternative),
    format(atom(Reason),
           'Consider ~w instead of ~w when parametric assumptions are violated',
           [Alternative, TestName]).


%% ═══════════════════════════════════════════════════════════════
%% EFFECT SIZE INTERPRETATION (Cohen's conventions)
%% ═══════════════════════════════════════════════════════════════

effect_size_interpretation(cohens_d, D, small)  :- abs(D) >= 0.2, abs(D) < 0.5.
effect_size_interpretation(cohens_d, D, medium) :- abs(D) >= 0.5, abs(D) < 0.8.
effect_size_interpretation(cohens_d, D, large)  :- abs(D) >= 0.8.
effect_size_interpretation(cohens_d, D, negligible) :- abs(D) < 0.2.

effect_size_interpretation(r, R, small)  :- abs(R) >= 0.1, abs(R) < 0.3.
effect_size_interpretation(r, R, medium) :- abs(R) >= 0.3, abs(R) < 0.5.
effect_size_interpretation(r, R, large)  :- abs(R) >= 0.5.
effect_size_interpretation(r, R, negligible) :- abs(R) < 0.1.

effect_size_interpretation(eta_squared, E, small)  :- E >= 0.01, E < 0.06.
effect_size_interpretation(eta_squared, E, medium) :- E >= 0.06, E < 0.14.
effect_size_interpretation(eta_squared, E, large)  :- E >= 0.14.
effect_size_interpretation(eta_squared, E, negligible) :- E < 0.01.

% Check if an LLM's interpretation matches the symbolic rules
interpretation_correct(Metric, Value, ClaimedLabel) :-
    effect_size_interpretation(Metric, Value, CorrectLabel),
    ClaimedLabel == CorrectLabel.

interpretation_incorrect(Metric, Value, ClaimedLabel, CorrectLabel) :-
    effect_size_interpretation(Metric, Value, CorrectLabel),
    ClaimedLabel \== CorrectLabel.


%% ═══════════════════════════════════════════════════════════════
%% STATISTICAL REASONING CHAINS
%% ═══════════════════════════════════════════════════════════════

% A complete analysis requires these steps in order
analysis_step(1, identify_variables).
analysis_step(2, determine_scale).
analysis_step(3, check_sample_size).
analysis_step(4, check_assumptions).
analysis_step(5, select_test).
analysis_step(6, compute_result).
analysis_step(7, compute_effect_size).
analysis_step(8, interpret_result).

% A step was skipped if any earlier step was not performed
step_skipped(Step, PerformedSteps) :-
    analysis_step(StepN, Step),
    analysis_step(EarlierN, EarlierStep),
    EarlierN < StepN,
    \+ member(EarlierStep, PerformedSteps).


%% ═══════════════════════════════════════════════════════════════
%% P-VALUE REASONING (common misinterpretations)
%% ═══════════════════════════════════════════════════════════════

% Common p-value misinterpretations that the LLM might produce
p_value_misinterpretation(probability_null_true,
    'P-value is NOT the probability that the null hypothesis is true').
p_value_misinterpretation(probability_replication,
    'P-value does NOT tell you the probability of replication').
p_value_misinterpretation(effect_size_indicator,
    'A small p-value does NOT mean a large effect size').
p_value_misinterpretation(practical_significance,
    'Statistical significance does NOT imply practical significance').

% Check for significance inflation
significance_inflation(P, N) :-
    P < 0.05,
    N > 1000,
    % With very large samples, even trivial effects are "significant"
    true.
