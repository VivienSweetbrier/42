# ==============================================================================
# bell_dial_sim_v4.bend
# V4: Hostile QA Patched (Optimal Classical Baseline + Measurement Dependence)
# ==============================================================================

def random_bit(seed, index, salt):
  let h = (seed + index) ^ salt
  let h = (h ^ (h >> 16)) * 0x7feb35
  let h = (h ^ (h >> 15)) * 0x846ca6
  let h = h ^ (h >> 16)
  return h % 2

def random_range(seed, index, salt, max_val):
  let h = (seed + index) ^ salt
  let h = (h ^ (h >> 16)) * 0x7feb35
  let h = (h ^ (h >> 15)) * 0x846ca6
  let h = h ^ (h >> 16)
  return h % max_val

# 1. THE SUPERDETERMINISTIC UNIVERSE
def generate_universe_state(seed, i, dial):
  # Settings are hash-generated; empirical frequencies must be reported.
  let x = random_bit(seed, i, 0x11)
  let y = random_bit(seed, i, 0x22)
  
  # Baseline hidden variable (Optimal Classical Strategy: Alice and Bob always output the same)
  let lam_a = random_bit(seed, i, 0x33)
  
  # The explicit P(lambda | x, y) joint distribution:
  let override_roll = random_range(seed, i, 0x55, 100)
  
  if override_roll < dial:
    # Dial triggered: Force lam_b so that (lam_a XOR lam_b) == (x AND y)
    let target_xor = x & y
    let forced_lam_b = lam_a ^ target_xor
    let lambda_payload = (lam_a << 1) | forced_lam_b
    return (x << 3) | (y << 2) | lambda_payload
  else:
    # Dial off: Fall back to the optimal classical baseline (lam_b = lam_a)
    # This gives exactly 75% when all setting pairs are weighted equally; the raw sampled rate depends on their frequencies.
    let lam_b = lam_a
    let lambda_payload = (lam_a << 1) | lam_b
    return (x << 3) | (y << 2) | lambda_payload

# 2. STRICT LOCAL RESPONSE FUNCTIONS
def alice(x, lam):
  return lam >> 1

def bob(y, lam):
  return lam & 1

# 3. INDEPENDENT REFEREE
def referee(x, y, a, b):
  let xor_ab = a ^ b
  let and_xy = x & y
  return xor_ab == and_xy

# 4. PARALLEL TREE FOLD
def simulate_trials(seed, depth, dial):
  bend d = 0, i = 0:
    when d < depth:
      let left  = fork(d + 1, i * 2)
      let right = fork(d + 1, (i * 2) + 1)
      return left + right
    else:
      let state = generate_universe_state(seed, i, dial)
      
      let x = (state >> 3) & 1
      let y = (state >> 2) & 1
      let lam = state & 3
      
      let a = alice(x, lam)
      let b = bob(y, lam)
      
      return referee(x, y, a, b)

def main():
  let master_seed = 42
  let depth = 12       # 4096 trials for smoother statistical distribution
  let dial = 40        # 40% override rate: Expected win rate = 40% + 0.6*(75%) = 85%
  return simulate_trials(master_seed, depth, dial)
