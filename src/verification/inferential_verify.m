% SPDX-License-Identifier: PMPL-1.0-or-later
% inferential_verify.m — Independent verification of inferential statistics.

function result = ttest_independent_verify(group1, group2, claimed)
  % TTEST_INDEPENDENT_VERIFY  Cross-check a claimed independent t-test result.
  %
  %   group1, group2 — numeric vectors (the raw data)
  %   claimed        — struct with .t_statistic, .p_value, .df, .cohens_d
  %
  %   Uses Welch's t-test (unequal variances assumed).

  tolerance = 1e-8;
  discrepancies = {};

  n1 = length(group1);
  n2 = length(group2);
  m1 = mean(group1);
  m2 = mean(group2);
  v1 = var(group1);
  v2 = var(group2);

  % Welch's t-statistic
  se = sqrt(v1/n1 + v2/n2);
  t_stat = (m1 - m2) / se;

  % Welch-Satterthwaite degrees of freedom
  num = (v1/n1 + v2/n2)^2;
  denom = (v1/n1)^2/(n1-1) + (v2/n2)^2/(n2-1);
  df = num / denom;

  % Two-tailed p-value from t-distribution
  % tcdf is available in Octave statistics package
  p_val = 2 * (1 - tcdf(abs(t_stat), df));

  % Cohen's d (pooled SD)
  s_pooled = sqrt(((n1-1)*v1 + (n2-1)*v2) / (n1+n2-2));
  d = (m1 - m2) / s_pooled;

  recomputed = struct( ...
    't_statistic', t_stat, ...
    'df', df, ...
    'p_value', p_val, ...
    'cohens_d', d, ...
    'mean_diff', m1 - m2, ...
    'se', se ...
  );

  % Cross-check
  check_pairs = { ...
    't_statistic', t_stat, claimed.t_statistic; ...
    'df',          df,     claimed.df; ...
    'p_value',     p_val,  claimed.p_value; ...
    'cohens_d',    d,      claimed.cohens_d ...
  };

  for i = 1:size(check_pairs, 1)
    name = check_pairs{i, 1};
    ours = check_pairs{i, 2};
    theirs = check_pairs{i, 3};
    if abs(ours - theirs) > tolerance
      msg = sprintf('DISCREPANCY in %s: claimed=%.15g, recomputed=%.15g', ...
                    name, theirs, ours);
      discrepancies{end+1} = msg;
    end
  end

  result = struct( ...
    'verified', isempty(discrepancies), ...
    'discrepancies', {discrepancies}, ...
    'recomputed', recomputed, ...
    'tolerance', tolerance, ...
    'engine', 'GNU Octave' ...
  );
end


function result = anova_oneway_verify(groups, claimed)
  % ANOVA_ONEWAY_VERIFY  Cross-check a claimed one-way ANOVA result.
  %
  %   groups  — cell array of numeric vectors
  %   claimed — struct with .f_statistic, .p_value, .df_between, .df_within

  tolerance = 1e-8;
  discrepancies = {};

  k = length(groups);
  ns = cellfun(@length, groups);
  N = sum(ns);
  means = cellfun(@mean, groups);
  grand_mean = mean(vertcat(groups{:}));

  % Sum of squares
  ss_between = sum(ns .* (means - grand_mean).^2);
  ss_within = 0;
  for i = 1:k
    ss_within = ss_within + sum((groups{i} - means(i)).^2);
  end

  df_between = k - 1;
  df_within = N - k;

  ms_between = ss_between / df_between;
  ms_within = ss_within / df_within;

  f_stat = ms_between / ms_within;
  p_val = 1 - fcdf(f_stat, df_between, df_within);

  % Effect sizes
  eta_sq = ss_between / (ss_between + ss_within);
  omega_sq = (ss_between - df_between * ms_within) / (ss_between + ss_within + ms_within);

  recomputed = struct( ...
    'f_statistic', f_stat, ...
    'p_value', p_val, ...
    'df_between', df_between, ...
    'df_within', df_within, ...
    'ss_between', ss_between, ...
    'ss_within', ss_within, ...
    'eta_squared', eta_sq, ...
    'omega_squared', omega_sq ...
  );

  check_pairs = { ...
    'f_statistic', f_stat,     claimed.f_statistic; ...
    'p_value',     p_val,      claimed.p_value; ...
    'df_between',  df_between, claimed.df_between; ...
    'df_within',   df_within,  claimed.df_within ...
  };

  for i = 1:size(check_pairs, 1)
    name = check_pairs{i, 1};
    ours = check_pairs{i, 2};
    theirs = check_pairs{i, 3};
    if abs(ours - theirs) > tolerance
      msg = sprintf('DISCREPANCY in %s: claimed=%.15g, recomputed=%.15g', ...
                    name, theirs, ours);
      discrepancies{end+1} = msg;
    end
  end

  result = struct( ...
    'verified', isempty(discrepancies), ...
    'discrepancies', {discrepancies}, ...
    'recomputed', recomputed, ...
    'tolerance', tolerance, ...
    'engine', 'GNU Octave' ...
  );
end


function result = chi_square_verify(observed, claimed)
  % CHI_SQUARE_VERIFY  Cross-check a claimed chi-square test result.
  %
  %   observed — matrix of observed frequencies
  %   claimed  — struct with .chi_square, .p_value, .df, .cramers_v

  tolerance = 1e-8;
  discrepancies = {};

  [r, c] = size(observed);
  N = sum(observed(:));
  row_sums = sum(observed, 2);
  col_sums = sum(observed, 1);
  expected = row_sums * col_sums / N;

  chi2 = sum(sum((observed - expected).^2 ./ expected));
  df = (r - 1) * (c - 1);
  p_val = 1 - chi2cdf(chi2, df);

  % Cramer's V
  k = min(r, c);
  cramers_v = sqrt(chi2 / (N * (k - 1)));

  recomputed = struct( ...
    'chi_square', chi2, ...
    'df', df, ...
    'p_value', p_val, ...
    'cramers_v', cramers_v ...
  );

  check_pairs = { ...
    'chi_square', chi2,      claimed.chi_square; ...
    'p_value',    p_val,     claimed.p_value; ...
    'df',         df,        claimed.df; ...
    'cramers_v',  cramers_v, claimed.cramers_v ...
  };

  for i = 1:size(check_pairs, 1)
    name = check_pairs{i, 1};
    ours = check_pairs{i, 2};
    theirs = check_pairs{i, 3};
    if abs(ours - theirs) > tolerance
      msg = sprintf('DISCREPANCY in %s: claimed=%.15g, recomputed=%.15g', ...
                    name, theirs, ours);
      discrepancies{end+1} = msg;
    end
  end

  result = struct( ...
    'verified', isempty(discrepancies), ...
    'discrepancies', {discrepancies}, ...
    'recomputed', recomputed, ...
    'tolerance', tolerance, ...
    'engine', 'GNU Octave' ...
  );
end
