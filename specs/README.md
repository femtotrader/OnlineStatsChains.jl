# OnlineStatsChains.jl Specifications

This directory contains the formal specifications for OnlineStatsChains.jl written in EARS (Easy Approach to Requirements Syntax) format.

## Specification Documents

### Core Specifications

- **[specs.md](specs.md)** - Main specification document
  - Version: 0.3.1
  - Contains all core requirements for the package
  - Defines the DAG framework, API, testing, documentation, and CI/CD requirements
  - Uses EARS format for clear, unambiguous requirements

### Future Feature Specifications

- **[rocket_integration.md](rocket_integration.md)** - Rocket.jl Integration Specification
  - Version: 0.1.0
  - Status: Future consideration (out of scope for v0.2.0-v0.3.0)
  - Defines optional reactive programming integration
  - Shows how to integrate with Rocket.jl without adding dependencies
  - Uses Julia's package extension system

## Specification Format

All specifications follow the **EARS (Easy Approach to Requirements Syntax)** format, which uses structured patterns:

- **Basic requirement:** "The system SHALL..."
- **Conditional:** "WHEN [condition], THEN the system SHALL..."
- **State-driven:** "WHILE [state], the system SHALL..."
- **Optional:** "The system MAY..." or "The system SHOULD..."
- **Complex:** "WHERE [condition] AND WHERE [condition], the system SHALL..."

## Requirement Naming Convention

Requirements follow this naming pattern: `REQ-<CATEGORY>-<NUMBER>`

### Categories

- **PKG**: Package structure and metadata
- **DAG**: DAG construction and structure
- **FIT**: Data input and fitting operations
- **FILTER**: Conditional edge filtering
- **TRANS**: Edge transformers
- **MULTI**: Multi-input node handling
- **VAL**: Value retrieval
- **INTRO**: Graph introspection
- **EVAL**: Evaluation strategies
- **PERF**: Performance requirements
- **USE**: Usability requirements
- **COMPAT**: Compatibility requirements
- **EXT**: Extensibility requirements
- **API**: API design requirements
- **ERR**: Error handling requirements
- **TEST**: Testing requirements
- **QA**: Quality assurance requirements (Aqua.jl)
- **DOC**: Documentation requirements
- **AITRANS**: AI transparency requirements
- **VC**: Version control and commit requirements
- **CI**: Continuous integration requirements
- **FUTURE**: Future considerations
- **ROCKET**: Rocket.jl integration (in rocket_integration.md)

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 0.3.1 | 2025-10-04 | Current version with modular file refactoring |
| 0.3.0 | 2025-10-03 | Added edge transformers and hybrid propagation |
| 0.2.0 | - | Added conditional edges (filters) |
| 0.1.0 | - | Initial specification |

## Adding New Specifications

When adding new feature specifications:

1. Create a new `.md` file in this directory
2. Follow the EARS format for requirements
3. Include version, date, and status in the header
4. Reference the parent requirement (e.g., `REQ-FUTURE-XXX`)
5. Link to the new spec from `specs.md` in section 9
6. Update this README with the new document

## Example Requirement

```markdown
**REQ-TRANS-001:** The `connect!()` function SHALL accept an optional `transform` keyword argument of type `Function`.

**REQ-TRANS-002:** WHEN `transform` is provided, THEN the edge SHALL propagate RAW data values through the transform before passing to the downstream node's `fit!()` method.
```

## Verification and Validation

Each requirement should be:

1. **Testable**: Can be verified through automated tests
2. **Unambiguous**: Has one clear interpretation
3. **Complete**: Fully specifies the behavior
4. **Consistent**: Doesn't contradict other requirements
5. **Traceable**: Linked to tests and implementation

## Related Documentation

- [Main Package Documentation](../docs/) - User-facing documentation
- [Test Suite](../test/) - Automated tests verifying requirements
- [Source Code](../src/) - Implementation of specifications

---

For questions or suggestions about these specifications, please open an issue in the GitHub repository.
