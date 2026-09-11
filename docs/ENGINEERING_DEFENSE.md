# Engineering Defense: Crane Simulator Academy

## 30-Second Explanation
"This simulator isn't just a video game; it's a deterministically verifiable physics engine built to evaluate human spatial reasoning. Instead of writing custom code for seven different cranes, I abstracted them into a universal data model driven by a single mathematical solver. This means if I fix the pendulum physics or wind math, all machines inherit the fix instantly. It's built to be automatically testable, ensuring that an AI or human can't break the physics without immediately failing the test suite."

## 2-Minute Explanation
"The core challenge with simulation engineering is state explosion. If you build a mobile crane, a tower crane, and an overhead crane as separate code paths, maintaining them becomes impossible. I solved this by treating the machine as data rather than bespoke code. There is only one core `machine_rig.gd` solver that takes a configuration file—like joint limits, winch speeds, and swing radii—and processes it. 

Deterministic physics buys us absolute reproducibility. Game engines are notoriously non-deterministic because they couple physics ticks to frame rate. I decoupled this entirely. If a student runs a scenario and fails, I can replay their exact inputs mathematically and get the exact same collision on the exact same frame. This makes headless automated testing possible. The test suite runs all 21 scenarios across all machines headlessly, verifying stability and pendulum dynamics against real-world math ($2\pi\sqrt{L/g}$). 

When building this with AI, the LLM confidently hallucinated that a crane hook's swing period depends on the mass of the load. I had to step in and correct the physics constraint: Galileo proved the period of a pendulum depends only on the length of the cable and gravity. The automated tests now lock that math in place, catching any future hallucinations."

## 5-Minute Technical Defense
### 1. Why the machine is data rather than bespoke code
Early prototypes treated each machine (overhead crane, lorry loader) as a unique subclass with its own input parsing and joint updates. This led to massive code duplication and testing nightmares. By moving to a data-driven catalogue, the `machine_rig` merely reads a 6-axis configuration matrix. To add a Ship-to-Shore (STS) gantry crane, I don't write new code; I write a JSON-like configuration block. This enforces a strict separation of concerns between state mutation (physics) and state definition (machine configuration).

### 2. What deterministic physics buys us
Standard game physics (like Godot's internal engine or Unity's PhysX) accumulates floating-point drift and integrates delta-time based on rendering speed. This makes replay and automated QA impossible. By implementing a fixed-step, engine-independent solver, `state_n+1` is always exactly the same for a given `state_n` and `input`. This guarantees that certification scenarios are fair, bugs are reproducible from logs, and headless CI can validate the entire curriculum in seconds without rendering a single frame.

### 3. How pendulum validation works
The test suite doesn't just check if the code runs; it checks if the math is sound. The pendulum validation test suspends a simulated load on a 10-meter cable, applies a lateral impulse, and measures the period of oscillation. It asserts that the measured period matches the theoretical $T = 2\pi\sqrt{L/g}$ to within a 0.15% margin of error. This proves the physics integrator isn't leaking energy or diverging over time.

### 4. How automated tests catch AI-generated mistakes
When utilizing AI agents to expand the machine catalog or add wind simulation, LLMs often write code that looks syntactically perfect but violates conservation of momentum or introduces NaN states during edge cases (like a cable length of 0). The deterministic test suite traverses every scenario using a fuzz-tester that applies maximum inputs to all axes simultaneously. This instantly caught an AI-generated bug where negative cable lengths caused a square-root-of-negative-one (`NaN`) cascade that corrupted the entire physics state.

### 5. One real example where human knowledge corrected the agent
During the development of the load moment calculation (which determines if a mobile crane tips over), the AI correctly calculated the center of mass but incorrectly assumed the tipping fulcrum was the center of the crane's footprint. Human expertise was required to correct the model: the fulcrum is the edge of the outrigger pad, and the moment arm changes dynamically as the crane slews (rotates). The AI lacked the domain-specific intuition of how real crane load charts are calculated, proving that agentic code generation still requires an expert engineer acting as the domain architect.
