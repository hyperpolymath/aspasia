% SPDX-License-Identifier: PMPL-1.0-or-later
% nonparametric_verify.m — Independent verification of nonparametric tests.

function result = mann_whitney_verify(group1, group2, claimed)
  % MANN_WHITNEY_VERIFY  Cross-check a claimed Mann-Whitney U test.
  %
  %   group1, group2 — numeric vectors
  %   claimed        — struct with .U, .p_value, .rank_biserial

  tolerance = 1e-6;  % Wider tolerance for rank-based methods
  discrepancies = {};

  n1 = length(group1);
  n2 = length(group2);
  combined = [group1(:); group2(:)];
  n = n1 + n2;

  % Rank all values (handle ties with average rank)
  [sorted_vals, sort_idx] = sort(combined);
  ranks = zeros(n, 1);
  i = 1;
  while i <= n
    j = i;
    while j <= n && sorted_vals(j) == sorted_vals(i)
      j = j + 1;
    end
    avg_rank = mean(i:(j-1));
    for k = i:(j-1)
      ranks(sort_idx(k)) = avg_rank;
    end
    i = j;
  end

  R1 = sum(ranks(1:n1));
  R2 = sum(ranks(n1+1:end));

  U1 = R1 - n1*(n1+1)/2;
  U2 = R2 - n2*(n2+1)/2;
  U = min(U1, U2);

  % Normal approximation for p-value
  mu_U = n1 * n2 / 2;
  sigma_U = sqrt(n1 * n2 * (n + 1) / 12);
  z = (U - mu_U) / sigma_U;
  p_val = 2 * normcdf(-abs(z));

  % Rank-biserial correlation
  rank_biserial = 1 - 2*U / (n1 * n2);

  recomputed = struct( ...
    'U', U, ...
    'U1', U1, ...
    'U2', U2, ...
    'z', z, ...
    'p_value', p_val, ...
    'rank_biserial', rank_biserial ...
  );

  check_pairs = { ...
    'U',       U,     claimed.U; ...
    'p_value', p_val, claimed.p_value ...
  };

  if isfield(claimed, 'rank_biserial')
    check_pairs(end+1, :) = {'rank_biserial', rank_biserial, claimed.rank_biserial};
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


function result = kruskal_wallis_verify(groups, claimed)
  % KRUSKAL_WALLIS_VERIFY  Cross-check a claimed Kruskal-Wallis test.
  %
  %   groups  — cell array of numeric vectors
  %   claimed — struct with .H, .p_value, .df

  tolerance = 1e-6;
  discrepancies = {};

  k = length(groups);
  ns = cellfun(@length, groups);
  N = sum(ns);
  combined = vertcat(groups{:});

  % Rank with ties
  [sorted_vals, sort_idx] = sort(combined);
  ranks = zeros(N, 1);
  i = 1;
  while i <= N
    j = i;
    while j <= N && sorted_vals(j) == sorted_vals(i)
      j = j + 1;
    end
    avg_rank = mean(i:(j-1));
    for m = i:(j-1)
      ranks(sort_idx(m)) = avg_rank;
    end
    i = j;
  end

  % Mean ranks per group
  idx = 1;
  R_means = zeros(k, 1);
  for g = 1:k
    group_ranks = ranks(idx:idx+ns(g)-1);
    R_means(g) = mean(group_ranks);
    idx = idx + ns(g);
  end

  % H statistic
  R_bar = (N + 1) / 2;
  H = 12 / (N * (N + 1)) * sum(ns .* (R_means - R_bar).^2);
  df = k - 1;
  p_val = 1 - chi2cdf(H, df);

  recomputed = struct( ...
    'H', H, ...
    'df', df, ...
    'p_value', p_val ...
  );

  check_pairs = { ...
    'H',       H,     claimed.H; ...
    'p_value', p_val, claimed.p_value; ...
    'df',      df,    claimed.df ...
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
