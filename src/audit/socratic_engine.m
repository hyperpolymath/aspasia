% SPDX-License-Identifier: PMPL-1.0-or-later
% socratic_engine.m — The Socratic audit engine.
%
% This is the heart of Aspasia. It intercepts a StatistEase transaction
% (input data + selected test + computed result + LLM explanation) and
% subjects it to cross-examination from three independent sources:
%
%   1. NUMERICAL VERIFICATION (Octave)
%      "Did the computation produce the correct numbers?"
%      → Calls verification/*.m functions
%
%   2. ONTOLOGICAL REASONING (Prolog)
%      "Was this the right test to run? Were assumptions checked?"
%      → Queries ontology/*.pl rules
%
%   3. INTERPRETATION AUDIT (Prolog + Octave)
%      "Does the LLM's explanation accurately represent the result?"
%      → Cross-references effect size labels, p-value language, etc.
%
% The output is a CHALLENGE REPORT, not a veto. Aspasia raises concerns;
% it does not block computation. The user sees both the result and the audit.
%
% GOVERNANCE MODEL
% ────────────────
% Aspasia operates as an AUDITOR, not a gatekeeper:
%   - It NEVER modifies StatistEase output
%   - It NEVER prevents computation
%   - It ALWAYS explains WHY it raises a concern
%   - It tracks its own accuracy (was the concern valid?)
%   - It learns from user feedback (Logtalk knowledge base)
%
% This is the Socratic method: not telling you what to think, but asking
% the questions that reveal whether you've thought it through.

function report = audit_transaction(transaction)
  % AUDIT_TRANSACTION  Full Socratic audit of a StatistEase transaction.
  %
  %   transaction — struct with fields:
  %     .test_name     — string, name of the statistical test
  %     .input_data    — struct with raw data vectors
  %     .result        — struct with computed values from StatistEase
  %     .explanation   — string, the LLM's natural language explanation
  %     .data_scale    — string, scale of measurement (nominal/ordinal/interval/ratio)
  %     .sample_size   — integer, total N
  %     .alpha         — float, significance level used
  %
  %   report — struct with:
  %     .challenges    — cell array of Socratic challenges
  %     .severity      — 'info' | 'warning' | 'concern' | 'error'
  %     .numerical_ok  — logical, did numbers check out?
  %     .ontological_ok — logical, was test appropriate?
  %     .interpretation_ok — logical, was explanation accurate?
  %     .summary       — string, one-line summary

  challenges = {};
  severity = 'info';

  %% ════════════════════════════════════════════════════════════
  %% PHASE 1: NUMERICAL VERIFICATION
  %% ════════════════════════════════════════════════════════════

  numerical_ok = true;
  numerical_result = struct();

  switch transaction.test_name
    case 'descriptive_stats'
      if isfield(transaction.input_data, 'data')
        numerical_result = descriptive_verify( ...
          transaction.input_data.data, transaction.result);
        numerical_ok = numerical_result.verified;
      end

    case 't_test_independent'
      if isfield(transaction.input_data, 'group1') && ...
         isfield(transaction.input_data, 'group2')
        numerical_result = ttest_independent_verify( ...
          transaction.input_data.group1, ...
          transaction.input_data.group2, ...
          transaction.result);
        numerical_ok = numerical_result.verified;
      end

    case {'pearson_correlation', 'spearman_correlation'}
      if isfield(transaction.input_data, 'x') && ...
         isfield(transaction.input_data, 'y')
        numerical_result = pearson_verify( ...
          transaction.input_data.x, ...
          transaction.input_data.y, ...
          transaction.result);
        numerical_ok = numerical_result.verified;
      end

    case 'simple_linear_regression'
      if isfield(transaction.input_data, 'x') && ...
         isfield(transaction.input_data, 'y')
        numerical_result = regression_verify( ...
          transaction.input_data.x, ...
          transaction.input_data.y, ...
          transaction.result);
        numerical_ok = numerical_result.verified;
      end
  end

  if ~numerical_ok
    severity = 'error';
    for i = 1:length(numerical_result.discrepancies)
      challenges{end+1} = struct( ...
        'type', 'numerical', ...
        'severity', 'error', ...
        'message', numerical_result.discrepancies{i}, ...
        'source', 'Octave independent recomputation' ...
      );
    end
  end

  %% ════════════════════════════════════════════════════════════
  %% PHASE 2: ONTOLOGICAL REASONING
  %% ════════════════════════════════════════════════════════════

  ontological_ok = true;

  % Check scale appropriateness
  scale_ok = check_scale_appropriateness( ...
    transaction.test_name, transaction.data_scale);
  if ~scale_ok.appropriate
    ontological_ok = false;
    severity = max_severity(severity, 'concern');
    challenges{end+1} = struct( ...
      'type', 'ontological', ...
      'severity', 'concern', ...
      'message', scale_ok.reason, ...
      'source', 'Statistical ontology (Stevens measurement scales)' ...
    );
  end

  % Check sample size
  size_ok = check_sample_size( ...
    transaction.test_name, transaction.sample_size);
  if ~size_ok.sufficient
    severity = max_severity(severity, 'warning');
    challenges{end+1} = struct( ...
      'type', 'ontological', ...
      'severity', 'warning', ...
      'message', size_ok.reason, ...
      'source', 'Statistical power requirements' ...
    );
  end

  % Check if assumptions were mentioned in explanation
  if ~contains_assumption_discussion(transaction.explanation, transaction.test_name)
    severity = max_severity(severity, 'info');
    challenges{end+1} = struct( ...
      'type', 'ontological', ...
      'severity', 'info', ...
      'message', sprintf('The explanation for %s does not discuss assumption checking. Readers may not know whether assumptions were verified.', ...
                         transaction.test_name), ...
      'source', 'Analysis completeness check' ...
    );
  end

  %% ════════════════════════════════════════════════════════════
  %% PHASE 3: INTERPRETATION AUDIT
  %% ════════════════════════════════════════════════════════════

  interpretation_ok = true;

  % Check effect size interpretation
  if isfield(transaction.result, 'cohens_d')
    correct_label = classify_effect_size('cohens_d', transaction.result.cohens_d);
    if ~isempty(transaction.explanation)
      claimed_label = extract_effect_label(transaction.explanation);
      if ~isempty(claimed_label) && ~strcmp(claimed_label, correct_label)
        interpretation_ok = false;
        severity = max_severity(severity, 'concern');
        challenges{end+1} = struct( ...
          'type', 'interpretation', ...
          'severity', 'concern', ...
          'message', sprintf('Effect size labeled as "%s" but Cohen''s d=%.3f is conventionally "%s"', ...
                            claimed_label, transaction.result.cohens_d, correct_label), ...
          'source', 'Cohen (1988) effect size conventions' ...
        );
      end
    end
  end

  % Check for p-value misinterpretation
  p_misinterp = check_p_value_language(transaction.explanation);
  for i = 1:length(p_misinterp)
    interpretation_ok = false;
    severity = max_severity(severity, 'concern');
    challenges{end+1} = struct( ...
      'type', 'interpretation', ...
      'severity', 'concern', ...
      'message', p_misinterp{i}, ...
      'source', 'P-value interpretation standards (ASA 2016 statement)' ...
    );
  end

  % Check for significance inflation with large N
  if isfield(transaction.result, 'p_value') && ...
     transaction.result.p_value < 0.05 && ...
     transaction.sample_size > 1000
    if isfield(transaction.result, 'cohens_d') && ...
       abs(transaction.result.cohens_d) < 0.2
      severity = max_severity(severity, 'warning');
      challenges{end+1} = struct( ...
        'type', 'interpretation', ...
        'severity', 'warning', ...
        'message', sprintf('p=%.4f with n=%d but effect size d=%.3f is negligible. Statistical significance here reflects sample size, not practical importance.', ...
                          transaction.result.p_value, transaction.sample_size, ...
                          transaction.result.cohens_d), ...
        'source', 'Significance inflation detection' ...
      );
    end
  end

  %% ════════════════════════════════════════════════════════════
  %% COMPILE REPORT
  %% ════════════════════════════════════════════════════════════

  if isempty(challenges)
    summary = sprintf('VERIFIED: %s computation and interpretation check out.', ...
                      transaction.test_name);
  else
    n_errors = sum(cellfun(@(c) strcmp(c.severity, 'error'), challenges));
    n_concerns = sum(cellfun(@(c) strcmp(c.severity, 'concern'), challenges));
    n_warnings = sum(cellfun(@(c) strcmp(c.severity, 'warning'), challenges));
    summary = sprintf('AUDIT: %d error(s), %d concern(s), %d warning(s) for %s', ...
                      n_errors, n_concerns, n_warnings, transaction.test_name);
  end

  report = struct( ...
    'challenges', {challenges}, ...
    'severity', severity, ...
    'numerical_ok', numerical_ok, ...
    'ontological_ok', ontological_ok, ...
    'interpretation_ok', interpretation_ok, ...
    'summary', summary, ...
    'engine', 'Aspasia (GNU Octave + Prolog)', ...
    'governance', 'auditor (non-blocking)' ...
  );
end


%% ════════════════════════════════════════════════════════════════
%% HELPER FUNCTIONS
%% ════════════════════════════════════════════════════════════════

function result = check_scale_appropriateness(test_name, data_scale)
  % Scale requirements from the ontology
  requirements = struct( ...
    't_test_independent', 'interval', ...
    't_test_paired', 'interval', ...
    't_test_one_sample', 'interval', ...
    'one_way_anova', 'interval', ...
    'chi_square_test', 'nominal', ...
    'pearson_correlation', 'interval', ...
    'spearman_correlation', 'ordinal', ...
    'simple_linear_regression', 'interval', ...
    'multiple_regression', 'interval', ...
    'mann_whitney_u', 'ordinal', ...
    'wilcoxon_signed_rank', 'ordinal', ...
    'kruskal_wallis', 'ordinal', ...
    'descriptive_stats', 'nominal' ...
  );

  scale_rank = struct('nominal', 0, 'ordinal', 1, 'interval', 2, 'ratio', 3);

  if isfield(requirements, test_name)
    required = requirements.(test_name);
    if scale_rank.(data_scale) >= scale_rank.(required)
      result = struct('appropriate', true, 'reason', '');
    else
      result = struct('appropriate', false, ...
        'reason', sprintf('%s requires %s-level data or higher, but data is %s-level. Consider a test designed for %s data.', ...
                         test_name, required, data_scale, data_scale));
    end
  else
    result = struct('appropriate', true, 'reason', 'Unknown test — no scale check available');
  end
end


function result = check_sample_size(test_name, n)
  minimums = struct( ...
    't_test_independent', 10, ...
    't_test_paired', 10, ...
    't_test_one_sample', 5, ...
    'one_way_anova', 15, ...
    'chi_square_test', 20, ...
    'pearson_correlation', 10, ...
    'simple_linear_regression', 20, ...
    'multiple_regression', 50, ...
    'mann_whitney_u', 10, ...
    'kruskal_wallis', 15, ...
    'descriptive_stats', 1 ...
  );

  if isfield(minimums, test_name)
    min_n = minimums.(test_name);
    if n >= min_n
      result = struct('sufficient', true, 'reason', '');
    else
      result = struct('sufficient', false, ...
        'reason', sprintf('%s with n=%d is below the recommended minimum of %d. Results may be unreliable.', ...
                         test_name, n, min_n));
    end
  else
    result = struct('sufficient', true, 'reason', '');
  end
end


function has_it = contains_assumption_discussion(explanation, test_name)
  % Tests that require assumption discussion
  assumption_tests = {'t_test_independent', 't_test_paired', 'one_way_anova', ...
                      'pearson_correlation', 'simple_linear_regression', ...
                      'multiple_regression'};
  if ~any(strcmp(test_name, assumption_tests))
    has_it = true;
    return;
  end

  keywords = {'normality', 'normal', 'assumption', 'homogeneity', 'variance', ...
              'linearity', 'homoscedasticity', 'independence'};
  explanation_lower = lower(explanation);
  has_it = any(cellfun(@(k) ~isempty(strfind(explanation_lower, k)), keywords));
end


function label = classify_effect_size(metric, value)
  switch metric
    case 'cohens_d'
      if abs(value) < 0.2
        label = 'negligible';
      elseif abs(value) < 0.5
        label = 'small';
      elseif abs(value) < 0.8
        label = 'medium';
      else
        label = 'large';
      end
    case 'r'
      if abs(value) < 0.1
        label = 'negligible';
      elseif abs(value) < 0.3
        label = 'small';
      elseif abs(value) < 0.5
        label = 'medium';
      else
        label = 'large';
      end
    otherwise
      label = 'unknown';
  end
end


function label = extract_effect_label(explanation)
  explanation_lower = lower(explanation);
  labels = {'negligible', 'small', 'medium', 'large', 'very large'};
  label = '';
  for i = 1:length(labels)
    if ~isempty(strfind(explanation_lower, labels{i}))
      label = labels{i};
    end
  end
end


function issues = check_p_value_language(explanation)
  issues = {};
  explanation_lower = lower(explanation);

  % Check for "probability that the null is true" misinterpretation
  if ~isempty(strfind(explanation_lower, 'probability')) && ...
     (~isempty(strfind(explanation_lower, 'null is true')) || ...
      ~isempty(strfind(explanation_lower, 'null hypothesis is true')))
    issues{end+1} = 'P-value is NOT the probability that the null hypothesis is true. It is the probability of observing data this extreme IF the null were true.';
  end

  % Check for "proves" language
  if ~isempty(strfind(explanation_lower, 'proves'))
    issues{end+1} = 'Statistical tests do not "prove" hypotheses. They provide evidence for or against them within a probabilistic framework.';
  end

  % Check for "accept the null" language
  if ~isempty(strfind(explanation_lower, 'accept the null'))
    issues{end+1} = 'We do not "accept" the null hypothesis. We either reject it or fail to reject it. Absence of evidence is not evidence of absence.';
  end
end


function s = max_severity(current, new)
  levels = struct('info', 0, 'warning', 1, 'concern', 2, 'error', 3);
  if levels.(new) > levels.(current)
    s = new;
  else
    s = current;
  end
end
