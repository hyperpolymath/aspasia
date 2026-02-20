% SPDX-License-Identifier: PMPL-1.0-or-later
% statistical_knowledge.lgt — Logtalk learning object for Elenchus.
%
% This is the knowledge base that evolves over time. As Elenchus audits
% more transactions, it accumulates knowledge about:
%   - Common statistical errors
%   - Patterns of LLM misinterpretation
%   - Test selection heuristics
%   - Domain-specific conventions
%
% Logtalk provides:
%   - Object-oriented logic programming (encapsulation, inheritance)
%   - Protocol-based interfaces
%   - Dynamic knowledge assertion/retraction
%   - Portable across Prolog implementations

:- object(statistical_knowledge).

    :- info([
        version is 1:0:0,
        author is 'Jonathan D.A. Jewell',
        date is 2026-02-20,
        comment is 'Elenchus statistical knowledge base — learns from audit history.'
    ]).

    %% ═══════════════════════════════════════════════════════════
    %% PUBLIC INTERFACE
    %% ═══════════════════════════════════════════════════════════

    :- public(known_error_pattern/3).
    :- public(test_recommendation/4).
    :- public(interpretation_rule/3).
    :- public(learn_from_audit/2).
    :- public(recall_similar/2).

    %% ═══════════════════════════════════════════════════════════
    %% KNOWN ERROR PATTERNS (seed knowledge)
    %% ═══════════════════════════════════════════════════════════

    :- dynamic(known_error_pattern/3).
    % known_error_pattern(PatternID, Description, Detection)

    known_error_pattern(
        p_value_as_probability,
        'LLM states p-value is the probability the null is true',
        contains(explanation, 'probability that the null')
    ).

    known_error_pattern(
        correlation_causation,
        'LLM implies causation from correlation',
        and(test_is(pearson_correlation), contains(explanation, 'cause'))
    ).

    known_error_pattern(
        nominal_t_test,
        'T-test applied to nominal/categorical data',
        and(test_is(t_test_independent), data_scale(nominal))
    ).

    known_error_pattern(
        small_n_regression,
        'Multiple regression with fewer observations than predictors',
        and(test_is(multiple_regression), n_less_than(predictors_plus_10))
    ).

    known_error_pattern(
        significance_without_effect,
        'Reports significance without mentioning effect size',
        and(p_significant, missing(effect_size_report))
    ).

    known_error_pattern(
        bonferroni_absent,
        'Multiple tests without family-wise error correction',
        and(n_tests_gt(1), missing(correction_mention))
    ).

    known_error_pattern(
        accept_null,
        'Uses "accept the null" instead of "fail to reject"',
        contains(explanation, 'accept the null')
    ).

    %% ═══════════════════════════════════════════════════════════
    %% TEST RECOMMENDATION RULES
    %% ═══════════════════════════════════════════════════════════

    :- dynamic(test_recommendation/4).
    % test_recommendation(Situation, Recommended, NotRecommended, Reason)

    test_recommendation(
        non_normal_small_n,
        mann_whitney_u,
        t_test_independent,
        'With non-normal data and small n, Mann-Whitney is more robust'
    ).

    test_recommendation(
        unequal_variances,
        welch_t_test,
        student_t_test,
        'Welch t-test does not assume equal variances'
    ).

    test_recommendation(
        ordinal_data,
        spearman_correlation,
        pearson_correlation,
        'Spearman requires only ordinal data; Pearson requires interval'
    ).

    %% ═══════════════════════════════════════════════════════════
    %% INTERPRETATION RULES
    %% ═══════════════════════════════════════════════════════════

    :- dynamic(interpretation_rule/3).
    % interpretation_rule(Context, Correct, Incorrect)

    interpretation_rule(
        large_n_small_p,
        'Statistically significant but effect size is negligible; practical importance is minimal',
        'Highly significant result demonstrates strong effect'
    ).

    interpretation_rule(
        non_significant,
        'Failed to reject the null hypothesis; insufficient evidence for a difference',
        'No difference exists between the groups'
    ).

    %% ═══════════════════════════════════════════════════════════
    %% LEARNING
    %% ═══════════════════════════════════════════════════════════

    :- dynamic(learned_pattern/4).
    % learned_pattern(Timestamp, PatternType, Description, Confidence)

    learn_from_audit(AuditRecord, Feedback) :-
        (   Feedback == valid ->
            % The challenge was correct — reinforce the pattern
            assertz(learned_pattern(
                AuditRecord.timestamp,
                confirmed,
                AuditRecord.test_audited,
                high
            ))
        ;   Feedback == invalid ->
            % The challenge was wrong — note the false positive
            assertz(learned_pattern(
                AuditRecord.timestamp,
                false_positive,
                AuditRecord.test_audited,
                low
            ))
        ;   Feedback == missed ->
            % We missed something — add a new detection rule
            assertz(learned_pattern(
                AuditRecord.timestamp,
                missed_detection,
                AuditRecord.test_audited,
                needs_investigation
            ))
        ).

    %% ═══════════════════════════════════════════════════════════
    %% RECALL
    %% ═══════════════════════════════════════════════════════════

    recall_similar(TestName, PastPatterns) :-
        findall(
            pattern(Time, Type, Conf),
            learned_pattern(Time, Type, TestName, Conf),
            PastPatterns
        ).

:- end_object.
