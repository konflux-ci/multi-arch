# Test findings

Things we find out while working on this repo.

## We cannot create MachineConfig resource in ROSA classic

There is a webhook preventing us from doing that that yield this output when we
try:
```
Error from server (Forbidden): error when creating "...": admission webhook
"regular-user-validation.managed.openshift.io" denied the request: Prevented
from accessing Red Hat managed resources. This is in an effort to prevent
harmful actions that may cause unintended consequences or affect the stability
of the cluster. If you have any questions about this, please reach out to
Red Hat support at https://access.redhat.com/support
```

This might apply to ROSA HCP as well. The immediate implication for us is that
we cannot go for a Kata-peer-PODs deployment architecture that assumes we would
be able to configure and run multiple CAA on the same cluster node and have
multiple corresponding runtime classes. An alternative that is available to us
is using differently configured CAA on different nodes and leverage the
`kata-remote` runtime class.

This does imply the Butane files we've created are not really needed.

## POD VM images are an issue

Upstream POD VM Images are wrapped in container images, and there is a script
that can take from images, unwrap them and do what is needed to get them to be 
AMIs in IBM cloud. But we've seen several issues when trying to actually boot
s390x VMs with those images:

1. The Fedora images do not seem to start any network services
2. The released Ubuntu images had issues running the Kata POD services as well

In the long term we need to establish a robust process of generating and
distributing RHEL-based AMIs for all relevant clouds.

## POD VM images may be tightly coupled with the CAA version

We spent a great deal of time building and trying various POD VM images, only
to repeatedly encounter the same networking issue. Ultimately the root cause was
that the CAA image we were using was from OSC 1.8 while our POD VM images were
built from the sources for OSC 1.9. Using the (pre-released at the time) OSC 1.9
CAA images finally resolved the issue.
