-- Prevents multiple PENDING or PROCESSING tasks of the same type from existing simultaneously.
-- This enables distributed deduplication across multiple app instances (e.g. k8s replicas).
CREATE UNIQUE INDEX "Task_type_active_unique" ON "Task" (type)
WHERE status IN ('PENDING', 'PROCESSING');
