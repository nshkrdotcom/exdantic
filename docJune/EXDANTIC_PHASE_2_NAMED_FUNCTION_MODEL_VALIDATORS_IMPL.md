# Phase 2: Named Function Model Validators Implementation

## Overview
Add model-level validation using named function references. Model validators run after field validation succeeds and can perform cross-field validation or data transformation.

## Goal
Enable DSPy-style model validation patterns:
```python
# DSPy/Pydantic equivalent
@model_validator(mode="after")
def validate_passwords(self):
    if self.password != self.password_confirmation:
        raise ValueError("passwords do not match")
    return self
```

## Implementation Strategy

### Phase 2A: Schema DSL Enhancement
Add `model_validator/1` macro that accepts function name references.

### Phase 2B: Validator Enhancement  
Extend validation pipeline to execute model validators after field validation.

### Phase 2C: Integration
Ensure model validators work with both struct and map schemas.

## Dependencies
No new external dependencies required. Build on Phase 1 foundation.

## Success Criteria
- Model validators execute after field validation
- Support multiple model validators in sequence  
- Work with both struct and map return types
- Proper error handling and path preservation
- All existing functionality preserved
- Performance impact < 10% overhead
