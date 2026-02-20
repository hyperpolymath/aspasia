% SPDX-License-Identifier: PMPL-1.0-or-later
% statistease_bridge.m — Interface between Elenchus and StatistEase.
%
% Elenchus observes StatistEase transactions via JSON exchange.
% It does NOT modify or intercept — it reads the transaction record
% after StatistEase has produced its result, and appends its audit.
%
% COMMUNICATION PROTOCOL
% ──────────────────────
% StatistEase writes a transaction JSON to a shared location (file or API).
% Elenchus reads it, audits it, and writes its challenge report alongside.
% The presenting LLM (or UI) shows both to the user.
%
% This is a PULL model, not PUSH. Elenchus is never in the critical path.

function report = audit_from_json(json_path)
  % AUDIT_FROM_JSON  Read a StatistEase transaction JSON and audit it.
  %
  %   json_path — path to a JSON file containing:
  %     { "test_name": "...",
  %       "input_data": { ... },
  %       "result": { ... },
  %       "explanation": "...",
  %       "data_scale": "...",
  %       "sample_size": N,
  %       "alpha": 0.05 }

  % Read JSON (Octave's jsondecode)
  fid = fopen(json_path, 'r');
  if fid == -1
    error('Cannot open transaction file: %s', json_path);
  end
  raw = fread(fid, Inf, 'char=>char')';
  fclose(fid);

  transaction = jsondecode(raw);

  % Ensure required fields exist
  required = {'test_name', 'result', 'data_scale', 'sample_size'};
  for i = 1:length(required)
    if ~isfield(transaction, required{i})
      error('Transaction missing required field: %s', required{i});
    end
  end

  % Default explanation to empty if not provided
  if ~isfield(transaction, 'explanation')
    transaction.explanation = '';
  end

  % Default alpha
  if ~isfield(transaction, 'alpha')
    transaction.alpha = 0.05;
  end

  % Run the audit
  report = audit_transaction(transaction);

  % Write the audit report alongside
  [dir, name, ~] = fileparts(json_path);
  report_path = fullfile(dir, [name '_audit.json']);
  report_json = jsonencode(report);
  fid = fopen(report_path, 'w');
  fprintf(fid, '%s', report_json);
  fclose(fid);

  fprintf('Audit complete: %s\n', report.summary);
  fprintf('Report written: %s\n', report_path);
end


function report = audit_from_struct(transaction)
  % AUDIT_FROM_STRUCT  Audit a StatistEase transaction directly from a struct.
  %
  %   For programmatic use when the transaction is already in memory.

  report = audit_transaction(transaction);
end


function print_report(report)
  % PRINT_REPORT  Display an audit report in human-readable form.

  fprintf('\n');
  fprintf('╔══════════════════════════════════════════════════════════════╗\n');
  fprintf('║  ELENCHUS AUDIT REPORT                                     ║\n');
  fprintf('║  Independent Neurosymbolic Verification                    ║\n');
  fprintf('╠══════════════════════════════════════════════════════════════╣\n');
  fprintf('║  Engine:     %s\n', report.engine);
  fprintf('║  Governance: %s\n', report.governance);
  fprintf('║  Severity:   %s\n', upper(report.severity));
  fprintf('╠══════════════════════════════════════════════════════════════╣\n');
  fprintf('║  Numerical:      %s\n', bool_str(report.numerical_ok));
  fprintf('║  Ontological:    %s\n', bool_str(report.ontological_ok));
  fprintf('║  Interpretation: %s\n', bool_str(report.interpretation_ok));
  fprintf('╠══════════════════════════════════════════════════════════════╣\n');

  if isempty(report.challenges)
    fprintf('║  No challenges raised. All checks passed.                  ║\n');
  else
    fprintf('║  CHALLENGES:                                                ║\n');
    for i = 1:length(report.challenges)
      c = report.challenges{i};
      fprintf('║                                                              ║\n');
      fprintf('║  [%s] %s\n', upper(c.severity), c.type);
      fprintf('║  %s\n', c.message);
      fprintf('║  Source: %s\n', c.source);
    end
  end

  fprintf('╠══════════════════════════════════════════════════════════════╣\n');
  fprintf('║  %s\n', report.summary);
  fprintf('╚══════════════════════════════════════════════════════════════╝\n');
  fprintf('\n');
end


function s = bool_str(b)
  if b
    s = 'PASS';
  else
    s = 'FAIL';
  end
end
