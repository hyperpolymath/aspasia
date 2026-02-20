% SPDX-License-Identifier: PMPL-1.0-or-later
% governance.m — Elenchus governance model.
%
% THE AUDITOR PRINCIPLE
% ─────────────────────
% Elenchus is an auditor, not a gatekeeper. This distinction matters:
%
%   GATEKEEPER (what we are NOT):
%     - Blocks computation when it disagrees
%     - Has veto power over results
%     - Creates bottlenecks
%     - Users route around it
%
%   AUDITOR (what we ARE):
%     - Observes and cross-checks independently
%     - Raises concerns with evidence and reasoning
%     - Tracks its own accuracy over time
%     - Users WANT to consult it because it makes them more confident
%
% This governance model is inspired by the Socratic method: Elenchus
% does not tell you what to think. It asks the questions that reveal
% whether you have thought it through.
%
% INDEPENDENCE GUARANTEES
% ───────────────────────
% 1. Different language (Octave, not Julia)
% 2. Different numerical backend (LAPACK, not OpenBLAS)
% 3. Different reasoning engine (Prolog, not LLM tool calls)
% 4. Separate repository (own maintainers, own update cycle)
% 5. Own Logtalk knowledge base (learns independently)
% 6. No shared state with StatistEase
% 7. No shared neural weights
%
% WHY THIS MATTERS
% ────────────────
% If StatistEase and Elenchus agree, confidence is high — two independent
% systems using different code paths reached the same answer.
%
% If they disagree, that is VALUABLE INFORMATION. The discrepancy reveals
% either a bug in one system or a genuine numerical sensitivity that the
% user should know about.
%
% Either way, the user wins.

function model = governance_model()
  % GOVERNANCE_MODEL  Return the Elenchus governance specification.

  model = struct();

  model.role = 'independent auditor';
  model.authority = 'advisory only — no veto, no blocking';

  model.principles = { ...
    'INDEPENDENCE: Elenchus maintains complete separation from StatistEase'; ...
    'TRANSPARENCY: Every challenge includes its source and reasoning'; ...
    'ACCOUNTABILITY: Elenchus tracks its own false positive rate'; ...
    'SOCRATIC: Questions, not assertions — reveal gaps in reasoning'; ...
    'NON-BLOCKING: Results are always delivered; audit accompanies, never prevents'; ...
    'LEARNABLE: Logtalk knowledge base evolves from user feedback'; ...
    'REPRODUCIBLE: All audits are deterministic given the same inputs' ...
  };

  model.severity_levels = struct( ...
    'info',    'Observation that may be useful but requires no action', ...
    'warning', 'Potential issue that merits attention', ...
    'concern', 'Likely problem that should be investigated', ...
    'error',   'Numerical discrepancy detected — results may be wrong' ...
  );

  model.feedback_loop = struct( ...
    'user_confirms_valid',   'Challenge accuracy += 1, strengthen rule weight', ...
    'user_dismisses_valid',  'Note dismissal, do not suppress future instances', ...
    'user_confirms_invalid', 'Challenge accuracy -= 1, reduce rule weight', ...
    'user_reports_missed',   'Add new rule to knowledge base' ...
  );

  model.independence_checks = { ...
    'No shared code with StatistEase'; ...
    'No shared numerical libraries'; ...
    'No shared neural models or weights'; ...
    'No shared configuration or state'; ...
    'Separate git repository with separate maintainers'; ...
    'Can be updated and deployed independently'; ...
    'Different programming language (Octave vs Julia)' ...
  };
end


function record = create_audit_record(transaction, report, timestamp)
  % CREATE_AUDIT_RECORD  Create a persistent audit trail entry.
  %
  %   Used by the Logtalk knowledge base to learn from past audits.

  record = struct( ...
    'timestamp', timestamp, ...
    'test_audited', transaction.test_name, ...
    'sample_size', transaction.sample_size, ...
    'data_scale', transaction.data_scale, ...
    'n_challenges', length(report.challenges), ...
    'severity', report.severity, ...
    'numerical_ok', report.numerical_ok, ...
    'ontological_ok', report.ontological_ok, ...
    'interpretation_ok', report.interpretation_ok, ...
    'user_feedback', '',     % Filled in later by user
    'feedback_valid', true   % Updated when user responds
  );
end


function stats = audit_accuracy_stats(audit_records)
  % AUDIT_ACCURACY_STATS  Self-assessment of Elenchus accuracy.
  %
  %   How often are our challenges valid? If we cry wolf too often,
  %   users will ignore us. If we miss real issues, we fail our purpose.

  total = length(audit_records);
  if total == 0
    stats = struct('total', 0, 'message', 'No audits recorded yet');
    return;
  end

  with_feedback = 0;
  true_positives = 0;  % Challenge raised, user confirmed valid
  false_positives = 0; % Challenge raised, user said invalid
  true_negatives = 0;  % No challenge, no issue
  false_negatives = 0; % No challenge, user reported missed issue

  for i = 1:total
    r = audit_records(i);
    if ~isempty(r.user_feedback)
      with_feedback = with_feedback + 1;
      if r.n_challenges > 0 && r.feedback_valid
        true_positives = true_positives + 1;
      elseif r.n_challenges > 0 && ~r.feedback_valid
        false_positives = false_positives + 1;
      elseif r.n_challenges == 0 && r.feedback_valid
        true_negatives = true_negatives + 1;
      else
        false_negatives = false_negatives + 1;
      end
    end
  end

  if with_feedback > 0
    precision = true_positives / max(1, true_positives + false_positives);
    recall = true_positives / max(1, true_positives + false_negatives);
  else
    precision = NaN;
    recall = NaN;
  end

  stats = struct( ...
    'total_audits', total, ...
    'with_feedback', with_feedback, ...
    'true_positives', true_positives, ...
    'false_positives', false_positives, ...
    'true_negatives', true_negatives, ...
    'false_negatives', false_negatives, ...
    'precision', precision, ...
    'recall', recall, ...
    'note', 'Elenchus tracks its own accuracy to calibrate challenge sensitivity' ...
  );
end
