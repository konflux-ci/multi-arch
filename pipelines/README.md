# Multi-arch Pipelines

This directory contains example Tekton pipelines demonstrating different approaches to
leveraging Kata peer-PODS.

## Setup

```shell
# Install kyverno
oc create -f https://github.com/kyverno/kyverno/releases/download/v1.11.1/install.yaml

# Create the required namespace and deploy config and task dependencies
oc new-project multi-arch-pipelines
oc apply -f pipelines/config
oc apply -f pipelines/tasks
```

## Native Tekton Approach

Peer-PODS can be used inside a `PipelineRun` with no additional dependencies.

### Try it
```shell
oc create -f pipelines/multi-arch-native.yaml
```

### Pros
- No additional dependencies required

### Cons
- Requires repetition in the `PipelineRun` definition.
- Pod templates are a runtime configuration which cannot be defined in a `Task`.
  In a `PipelineRun` they must be defined using `spec.taskRunSpecs`, not within the pipeline tasks.
- `spec.taskRunSpecs` requires named references to their respective pipeline task. It's not
  possible to reference a specific combination from a pipeline task using the `Matrix` feature.

> **Note:** The inability to declare the pod template on a task is a known issue
  (see issue [#6742](https://github.com/tektoncd/pipeline/issues/6742)).
  The proposed solution in PR [#8599](https://github.com/tektoncd/pipeline/pull/8599)
  may solve most noted drawbacks.

## Matrix Params w/Kyverno

### Try it
```shell
oc create -f pipelines/multi-arch-matrix-kyverno.yaml
```

### Pros
- Matrix params are supported. Adding a platform is simple with no configuration repetition.
- Can easily be adapted if/when pod templates can be defined within `Tasks`.

### Cons
- `Pods` are the most heavily used resources in Konflux clusters. Enforcing a Kyverno
  policy at resource creation time may introduce bottlenecks or other performance issues.
- The policy requires an additional API call to retrieve a param value from the `TaskRun` which
  generated the `Pod`. It's not possible for the policy to select the `TaskRun` directly and mutate
  its pod template when the task definition is not inline (i.e. using a `taskRef`).
  In such a scenario, the `Task` annotations are propagated to the `TaskRun` with an update
  operation rather than during creation. A Tekton admission webhook prevents the `TaskRun` spec
  from being modified after the resource has been created.

## Privileged Pods w/Kyverno

Granting elevated privileges to peer pods is as simple as applying the needed configuration on a
`TaskRun`/`Pod` spec except the `SecurityContextConstraints` (SCC) linked to the build
pipeline runner service accounts don't allow for this in Konflux. To overcome this issue we
could create another service account and link that to a different SCC with more open permissions.
In this example we use the platform provided `privileged` SCC.
However, we also need something (Kyverno), to prevent use of the service account in any other
workloads (those not using the `kata-remote` runtime class).

### Try it
```shell
oc create -f pipelines/multi-arch-matrix-kyverno-privileged.yaml
```

### Pros
- Works nicely as a cascading rule when combined with the Kyverno solution for matrix params.

### Cons
- Overhead from executing another Kyverno policy rule.
- Requires the user to specify yet another service account in their `PipelineRuns`.
- Requires creation of another service account per component in each tenant (as permitted).
  The build service is responsible for creating the service accounts.
