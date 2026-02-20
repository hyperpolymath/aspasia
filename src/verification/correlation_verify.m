% SPDX-License-Identifier: PMPL-1.0-or-later
% correlation_verify.m — Independent verification of correlation and regression.

function result = pearson_verify(x, y, claimed)
  % PEARSON_VERIFY  Cross-check a claimed Pearson correlation.
  %
  %   x, y    — numeric vectors
  %   claimed — struct with .r, .p_value, .ci_lower, .ci_upper

  tolerance = 1e-8;
  discrepancies = {};

  n = length(x);
  r = corr(x(:), y(:));

  % t-statistic for significance
  t_stat = r * sqrt((n - 2) / (1 - r^2));
  p_val = 2 * (1 - tcdf(abs(t_stat), n - 2));

  % Fisher z transformation for CI
  z = atanh(r);
  se_z = 1 / sqrt(n - 3);
  z_crit = 1.96;  % 95% CI
  ci_lower = tanh(z - z_crit * se_z);
  ci_upper = tanh(z + z_crit * se_z);

  % R-squared
  r_squared = r^2;

  recomputed = struct( ...
    'r', r, ...
    'r_squared', r_squared, ...
    'p_value', p_val, ...
    'ci_lower', ci_lower, ...
    'ci_upper', ci_upper, ...
    't_statistic', t_stat, ...
    'n', n ...
  );

  check_pairs = { ...
    'r',        r,        claimed.r; ...
    'p_value',  p_val,    claimed.p_value ...
  };

  % CI check (if provided)
  if isfield(claimed, 'ci_lower')
    check_pairs(end+1, :) = {'ci_lower', ci_lower, claimed.ci_lower};
    check_pairs(end+1, :) = {'ci_upper', ci_upper, claimed.ci_upper};
  end

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


function result = regression_verify(x, y, claimed)
  % REGRESSION_VERIFY  Cross-check a claimed simple linear regression.
  %
  %   x, y    — numeric vectors
  %   claimed — struct with .intercept, .slope, .r_squared, .f_statistic, .p_value

  tolerance = 1e-8;
  discrepancies = {};

  n = length(x);
  x = x(:);
  y = y(:);

  % OLS via normal equations (deliberately different from Julia's approach)
  X = [ones(n, 1), x];
  beta = (X' * X) \ (X' * y);  % Octave uses different LAPACK path than Julia
  intercept = beta(1);
  slope = beta(2);

  % Predictions and residuals
  y_hat = X * beta;
  residuals = y - y_hat;
  y_bar = mean(y);

  % Sum of squares
  ss_total = sum((y - y_bar).^2);
  ss_regression = sum((y_hat - y_bar).^2);
  ss_residual = sum(residuals.^2);

  r_squared = ss_regression / ss_total;
  adj_r_squared = 1 - (1 - r_squared) * (n - 1) / (n - 2);

  % F-statistic
  ms_regression = ss_regression / 1;
  ms_residual = ss_residual / (n - 2);
  f_stat = ms_regression / ms_residual;
  p_val = 1 - fcdf(f_stat, 1, n - 2);

  % Standard error of estimate
  se = sqrt(ms_residual);

  recomputed = struct( ...
    'intercept', intercept, ...
    'slope', slope, ...
    'r_squared', r_squared, ...
    'adj_r_squared', adj_r_squared, ...
    'f_statistic', f_stat, ...
    'p_value', p_val, ...
    'se', se, ...
    'ss_total', ss_total, ...
    'ss_regression', ss_regression, ...
    'ss_residual', ss_residual ...
  );

  check_pairs = { ...
    'intercept',   intercept,  claimed.intercept; ...
    'slope',       slope,      claimed.slope; ...
    'r_squared',   r_squared,  claimed.r_squared; ...
    'f_statistic', f_stat,     claimed.f_statistic; ...
    'p_value',     p_val,      claimed.p_value ...
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
