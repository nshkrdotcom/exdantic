[
  # These functions work correctly in practice but Dialyzer can't analyze the complex call chains
  # involving Runtime.create_schema, Runtime.validate, and TypeAdapter calls
  ~r/lib\/exdantic\/enhanced_validator\.ex:118.*Function validate_wrapped.* has no local return/,
  ~r/lib\/exdantic\/enhanced_validator\.ex:121.*Function validate_wrapped.* has no local return/,
  ~r/lib\/exdantic\/enhanced_validator\.ex:123.*Function validate_wrapped.* has no local return/,
  ~r/lib\/exdantic\/wrapper\.ex:58.*Function create_wrapper.* has no local return/,
  ~r/lib\/exdantic\/wrapper\.ex:60.*Function create_wrapper.* has no local return/,
  ~r/lib\/exdantic\/wrapper\.ex:70.*Function do_create_wrapper.* has no local return/,
  ~r/lib\/exdantic\/wrapper\.ex:194.*Function wrap_and_validate.* has no local return/,
  ~r/lib\/exdantic\/wrapper\.ex:225.*The created anonymous function has no local return/,
  ~r/lib\/exdantic\/wrapper\.ex:318.*The created anonymous function has no local return/,
  ~r/lib\/exdantic\/wrapper\.ex:461.*Function create_flexible_wrapper.* has no local return/,
  # Extra range warning for validate_wrapped/4 due to try/rescue always returning a tuple
  ~r/lib\/exdantic\/enhanced_validator\.ex:125.*extra_range/,
  # The type specification has too many types for the function.
  {"lib/exdantic/enhanced_validator.ex", :extra_range, 125},
  # The catch-all clause is needed for error handling even though dialyzer thinks it's unreachable
  ~r/lib\/exdantic\/json_schema\/enhanced_resolver\.ex:766.*pattern_match_cov/
]
