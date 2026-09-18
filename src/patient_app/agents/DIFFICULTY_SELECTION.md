# Model training for dynamic difficulty selection during gameplay

- **Requirements**: UCB1 Multi-Armed Bandit, Multi-Layer Perceptron (exported as TFLite)
- **Procedure**: 
    - The stats and metrics of the patient are generated as accurately as possible
    - For each round $N$, UCB1 calculates the upper confidence score for each arm $i$:

        $$UCB_i = \bar{X}_i + c \sqrt{\frac{2 \ln N}{n_i}}$$

        where:
        - $\bar{X}_i$: Clinical reward score (e.g., maximizing the patient's "Zone of Proximal Development" with ~75% accuracy and low hesitation).
        - $c \sqrt{\frac{2 \ln N}{n_i}}$: Exploration confidence bonus based on uncertainty.

    - Run patient logs through UCB1. Instead of keeping a single winner, record the full vector of UCB1 values for every telemetry state:

        $$\text{Input: } [latency, accuracy, hesitation, error\_burst] \longrightarrow \text{Target: } [UCB_{L1}, UCB_{L2}, UCB_{L3}]$$

    - Apply a temperature softmax over the UCB scores to turn them into soft target probabilities:

        $$P(arm_i) = \frac{\exp(UCB_i / \tau)}{\sum_j \exp(UCB_j / \tau)}$$

    - Train your 3-layer MLP using KL-Divergence or Mean Squared Error (MSE) against these confidence vectors rather than standard cross-entropy.
