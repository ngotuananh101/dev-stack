/// Live state of a supervised program. In-memory only — never persisted.
enum SupervisorStatus {
  stopped,
  starting,
  running,
  stopping,
  restarting,
  fatal,
}
