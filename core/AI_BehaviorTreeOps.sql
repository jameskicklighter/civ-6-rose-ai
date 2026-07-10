-- Rose AI behavior-tree operation registration.
-- The base game does not define OP_PILLAGE as an AiOperationType.
-- RH AI and Real Strategy both add it before defining their district-pillage operation.

INSERT OR IGNORE INTO AiOperationTypes (OperationType, Value)
SELECT 'OP_PILLAGE', MAX(Value) + 1
FROM AiOperationTypes;

-- Limit the new pillage operation type like other operation types.
-- BaseOperationsLimits caps total active operations of this type.
-- PerWarOperationsLimits caps active operations per war.
INSERT OR IGNORE INTO AiFavoredItems (ListType, Item, Value) VALUES
('BaseOperationsLimits',   'OP_PILLAGE', 1),
('PerWarOperationsLimits', 'OP_PILLAGE', 1);
