unit Octopus.Resources;

interface

resourcestring
  SBuilderCurrentNodeError       = 'Current element is not a flow node';
  SBuilderCurrentTransitionError = 'Current element is not a transition';
  SErrorDuplicateStartEvent      = 'Duplicate start event';
  SErrorElementNotFound          = 'Element "%s" not found';
  SErrorEndEventOutgoing         = 'Outgoing transition not allowed in end events';
  SErrorJsonInvalidInstanceType  = 'Invalid "%s". Type mismatch between "%s" and "%s"';
  SErrorJsonInvalidProperty      = 'Property "%s" does not refer to a valid property in entity type "%s"';
  SErrorJsonTypeNotFound         = 'Could not deserialize JSON object. Type "%s" not found';
  SErrorNoIncomingTransition     = 'Missing incoming transition in flow node';
  SErrorNoOutgoingTransition     = 'Missing outgoing transition in start event';
  SErrorNoSourceNode             = 'Missing source node in transition';
  SErrorNoStartEvent             = 'Missing start event';
  SErrorNoTargetNode             = 'Missing target node in transition';
  SErrorProcessNotAssigned       = 'Process not assigned';
  SErrorStartEventIncoming       = 'Incoming transition not allowed in start events';
  SErrorUnsupportedDataType      = 'Unsupported datatype: %s';
  SErrorVariableNotFound         = 'Variable "%s" not found';

implementation

end.

