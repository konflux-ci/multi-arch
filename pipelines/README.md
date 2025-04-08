# Multi-arch Pipelines

This directory contains example Tekton pipelines demonstrating different approaches to
leveraging Kata peer-PODS.

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
- Requires the `v1beta1` version of the `PipelineRun` API.

> **Note:** The inability to declare the pod template on a task is a known issue
  (see issue [#6742](https://github.com/tektoncd/pipeline/issues/6742)).
  The proposed solution in PR [#8599](https://github.com/tektoncd/pipeline/pull/8599)
  may solve most noted drawbacks.

