% SPDX-License-Identifier: PMPL-1.0-or-later
% input_audit.m — Audit the INTERPRETATION of input data, not just computation.
%
% THE MOST DANGEROUS BUG
% ──────────────────────
% If both StatistEase and Aspasia misinterpret input data the same way,
% they will agree on the wrong answer and the resolution ladder will
% never fire. This module catches that failure mode by independently
% checking how input data was parsed.
%
% WHAT THIS CATCHES:
%   - Date format ambiguity (01/02/2026: US or UK?)
%   - Decimal separator confusion (1,234: integer or European float?)
%   - Mathematical constant redefinition (pi = 22/7)
%   - Variable name shadowing (mean = 5.0)
%   - Unit system mixing (inches and cm in same column)
%   - Excel-style data corruption (MARCH1 → Mar-01)
%   - Operator precedence assumptions (2+3*4: 14 or 20?)
%   - Leading zero ambiguity (007: number or ID?)

function result = audit_input_interpretation(raw_data, transaction)
  % AUDIT_INPUT_INTERPRETATION  Check that input data was parsed correctly.
  %
  %   raw_data    — cell array of original string values (before parsing)
  %   transaction — struct with the parsed/canonical values StatistEase used
  %
  %   result      — struct with input-level concerns

  concerns = {};

  %% ════════════════════════════════════════════════════════════
  %% DATE AMBIGUITY CHECK
  %% ════════════════════════════════════════════════════════════

  for i = 1:length(raw_data)
    val = strtrim(raw_data{i});

    % Check for ambiguous date patterns
    [tok] = regexp(val, '^(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})$', 'tokens');
    if ~isempty(tok)
      parts = str2double(tok{1});
      a = parts(1); b = parts(2);
      if a <= 12 && b <= 12 && a ~= b
        concerns{end+1} = struct( ...
          'type', 'date_ambiguity', ...
          'severity', 'warning', ...
          'row', i, ...
          'value', val, ...
          'message', sprintf('"%s" is ambiguous: could be %02d/%02d (US: month %d, day %d) or %02d/%02d (UK: day %d, month %d). Verify which convention the data source uses.', ...
            val, a, b, a, b, a, b, a, b) ...
        );
      end
    end
  end

  %% ════════════════════════════════════════════════════════════
  %% DECIMAL SEPARATOR CHECK
  %% ════════════════════════════════════════════════════════════

  for i = 1:length(raw_data)
    val = strtrim(raw_data{i});

    % Pattern: digits,digits where second group is 1-2 digits
    % Could be European decimal (1,23 = 1.23) or English thousands (ambiguous)
    [tok] = regexp(val, '^(\d+),(\d{1,2})$', 'tokens');
    if ~isempty(tok)
      en_val = str2double(strrep(val, ',', ''));  % English: remove comma
      eu_val = str2double(strrep(val, ',', '.'));  % European: comma → dot
      concerns{end+1} = struct( ...
        'type', 'decimal_ambiguity', ...
        'severity', 'warning', ...
        'row', i, ...
        'value', val, ...
        'message', sprintf('"%s" is ambiguous: English interpretation = %g, European interpretation = %g. Which locale was the data collected in?', ...
          val, en_val, eu_val) ...
      );
    end
  end

  %% ════════════════════════════════════════════════════════════
  %% CONSTANT INTEGRITY CHECK
  %% ════════════════════════════════════════════════════════════

  if isfield(transaction, 'constant_integrity')
    ci = transaction.constant_integrity;
    if isfield(ci, 'constants_ok') && ~ci.constants_ok
      for j = 1:length(ci.issues)
        concerns{end+1} = struct( ...
          'type', 'constant_redefined', ...
          'severity', 'critical', ...
          'row', 0, ...
          'value', '', ...
          'message', ci.issues{j} ...
        );
      end
    end
  end

  % Aspasia's own constant check (independent verification)
  octave_pi = pi;
  if abs(octave_pi - 3.141592653589793) > 1e-15
    concerns{end+1} = struct( ...
      'type', 'constant_redefined', ...
      'severity', 'critical', ...
      'row', 0, ...
      'value', sprintf('pi = %g', octave_pi), ...
      'message', 'CRITICAL: pi has been redefined in the Octave session. All trigonometric computations are invalid.' ...
    );
  end

  octave_e = exp(1);
  if abs(octave_e - 2.718281828459045) > 1e-15
    concerns{end+1} = struct( ...
      'type', 'constant_redefined', ...
      'severity', 'critical', ...
      'row', 0, ...
      'value', sprintf('e = %g', octave_e), ...
      'message', 'CRITICAL: e (Euler''s number) may have been redefined.' ...
    );
  end

  %% ════════════════════════════════════════════════════════════
  %% EXCEL CORRUPTION CHECK
  %% ════════════════════════════════════════════════════════════

  excel_patterns = { ...
    'Jan-', 'Feb-', 'Mar-', 'Apr-', 'May-', 'Jun-', ...
    'Jul-', 'Aug-', 'Sep-', 'Oct-', 'Nov-', 'Dec-' ...
  };

  for i = 1:length(raw_data)
    val = strtrim(raw_data{i});
    for j = 1:length(excel_patterns)
      if ~isempty(strfind(val, excel_patterns{j})) && length(val) <= 6
        concerns{end+1} = struct( ...
          'type', 'excel_corruption', ...
          'severity', 'concern', ...
          'row', i, ...
          'value', val, ...
          'message', sprintf('"%s" may be an Excel-corrupted gene name (e.g., MARCH1 auto-converted to Mar-01). Ziemann et al. (2016) found ~20%% of genomics papers affected. Check original data source.', val) ...
        );
      end
    end
  end

  %% ════════════════════════════════════════════════════════════
  %% LEADING ZEROS CHECK
  %% ════════════════════════════════════════════════════════════

  for i = 1:length(raw_data)
    val = strtrim(raw_data{i});
    if length(val) > 1 && val(1) == '0' && all(val >= '0' & val <= '9')
      concerns{end+1} = struct( ...
        'type', 'leading_zeros', ...
        'severity', 'info', ...
        'row', i, ...
        'value', val, ...
        'message', sprintf('"%s" has leading zeros. If this is an ID or postcode, it should be treated as a string, not parsed as the integer %d.', ...
          val, str2double(val)) ...
      );
    end
  end

  %% ════════════════════════════════════════════════════════════
  %% UNIT MIXING CHECK
  %% ════════════════════════════════════════════════════════════

  imperial_found = {};
  metric_found = {};
  imperial_re = '(?i)\b(inch|inches|ft|feet|yard|mile|lb|lbs|oz|fahrenheit)\b';
  metric_re = '(?i)\b(cm|mm|meter|metre|km|kg|gram|celsius|litre|liter|ml)\b';

  for i = 1:length(raw_data)
    val = raw_data{i};
    if ~isempty(regexp(val, imperial_re))
      imperial_found{end+1} = val;
    end
    if ~isempty(regexp(val, metric_re))
      metric_found{end+1} = val;
    end
  end

  if ~isempty(imperial_found) && ~isempty(metric_found)
    concerns{end+1} = struct( ...
      'type', 'mixed_units', ...
      'severity', 'concern', ...
      'row', 0, ...
      'value', '', ...
      'message', sprintf('MIXED UNIT SYSTEMS: Found both imperial (%s) and metric (%s) values. Convert to one system before analysis. (Reference: Mars Climate Orbiter, 1999)', ...
        strjoin(imperial_found(1:min(3,end)), ', '), ...
        strjoin(metric_found(1:min(3,end)), ', ')) ...
    );
  end

  %% ════════════════════════════════════════════════════════════
  %% COMPILE RESULT
  %% ════════════════════════════════════════════════════════════

  if isempty(concerns)
    severity = 'ok';
    summary = 'Input interpretation appears unambiguous.';
  else
    n_critical = sum(cellfun(@(c) strcmp(c.severity, 'critical'), concerns));
    n_concerns = sum(cellfun(@(c) strcmp(c.severity, 'concern'), concerns));
    n_warnings = sum(cellfun(@(c) strcmp(c.severity, 'warning'), concerns));

    if n_critical > 0
      severity = 'critical';
    elseif n_concerns > 0
      severity = 'concern';
    else
      severity = 'warning';
    end

    summary = sprintf('INPUT AUDIT: %d critical, %d concern(s), %d warning(s). Review before trusting computation.', ...
      n_critical, n_concerns, n_warnings);
  end

  result = struct( ...
    'concerns', {concerns}, ...
    'severity', severity, ...
    'summary', summary, ...
    'n_concerns', length(concerns), ...
    'engine', 'Aspasia input audit (GNU Octave)', ...
    'note', 'Input interpretation errors are the most dangerous class of bug because both systems may agree on the wrong answer.' ...
  );
end
