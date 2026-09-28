# Costs and teardown

Review the current official GKE and networking pricing before apply; no fixed dollar total is promised. Actual spending depends on duration, autoscaling, regional quotas, traffic, logs and query volume. One applicable cluster-management credit is not two free clusters. Set project-specific billing alerts and an agreed teardown time.

1. Preserve sanitized evidence, dashboard export and Terraform state.
2. Run `terraform -chdir=terraform/edge destroy`. This detaches NEGs and removes the forwarding rules, public global IP and certificate.
3. Use `scripts/cleanup.sh` for monitoring/app removal and core deletion, or follow its explicit commands manually. The script retains Terraform's interactive destructive-action prompts.
4. Delete Services before clusters so GKE can reconcile/delete their NEGs. Confirm the NEGs disappear. If the controller is delayed, investigate before proceeding.
5. Disable cluster deletion protection with a normal Terraform apply, then destroy core.
6. The BigQuery dataset intentionally refuses deletion while it contains tables. Preserve needed logs, then explicitly delete the disposable dataset's tables in BigQuery and rerun destroy. Alternatively, review changing `delete_contents_on_destroy=true` solely for deliberate disposal of this dataset.
7. A Terraform-created project has deletion policy PREVENT. Core destroy can stop at the protected project. Keep the project, or remove it from Terraform state only after other managed resources are deleted if you intend to retain it. Project deletion is a separate deliberate decision; never delete a shared project.
8. Check the console for residual GKE clusters, node disks, NEGs, forwarding rules, global addresses, routers/NAT, Artifact Registry images and BigQuery storage. Review Billing afterward; billing reports can lag.

Deleting a Git repository or closing Cloud Shell does not stop cloud charges. Do not discard Terraform state until all intended resource deletions are confirmed.
