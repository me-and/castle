import subprocess
import json
import re
import datetime
from typing import Union, Callable, NoReturn, TypeVar, Optional, TypeAlias, ClassVar, Any, Iterable, Literal
import sys
import functools
import os
import collections.abc
import uuid
from copy import deepcopy
from dataclasses import dataclass

import psutil


sprint = functools.partial(print, file=sys.stderr)


DEBUG = False


DATETIME_CALC_RE = re.compile(r'^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d$')

T = TypeVar('T', str, int, uuid.UUID, list[uuid.UUID], datetime.datetime, list[str])
U = TypeVar('U')
V = TypeVar('V')

def list_map(f: Callable[[U], V]) -> Callable[[list[U]], list[V]]:
    return lambda x: list(map(f, x))

@dataclass(frozen=True)
class Column:
    name: str
    json_decoder: Optional[Callable[[Any], Any]] = None  # TODO fixup typing
    json_pre_dump: Optional[Callable[[Any], Any]] = None  # TODO fixup typing
    required: bool = False
    read_only: bool = False

    _by_name: ClassVar[dict[str, 'Column']] = {}

    def __post_init__(self) -> None:
        self._by_name[self.name] = self

    @staticmethod
    def datetime_pre_dump(d: datetime.datetime) -> str:
        return d.astimezone(datetime.UTC).strftime('%Y%m%dT%H%M%SZ')

    @classmethod
    def by_name(cls, name: str) -> 'Column':
        if not cls._by_name:
            # Creating the instances will automatically populate cls._by_name

            # Singular fields
            Column('annotations')
            Column('depends', list_map(uuid.UUID), list_map(str))
            Column('description', required=True)
            Column('id', read_only=True)
            Column('mask', read_only=True)  # TODO Can this be more structured?
            Column('parent', uuid.UUID, str)  # type: ignore[arg-type]  # mypy doesn't think uuid.UUID is callable
            Column('recur')  # TODO Can this be more structured?
            Column('rtype')  # TODO Can this be more structured?
            Column('status')  # TODO Can this be more structured?
            Column('tags')
            Column('template', uuid.UUID)
            Column('urgency')
            Column('uuid', uuid.UUID, str, read_only=True)

            # TODO These are handled as read-only ints, but it might be
            # possible to do better here once I work out how they're used.
            for k in ('imask', 'last'):
                Column(k, read_only=True)

            # Modifiable string entries
            for k in ('priority', 'project'):
                Column(k)

            # Modifiable date/time entries
            for k in ('due', 'end', 'entry', 'modified', 'scheduled', 'start',
                      'until', 'wait'):
                Column(k, datetime.datetime.fromisoformat, cls.datetime_pre_dump)

            # UDA durations.  TODO Make these dynamic.  TODO Make these more
            # structured.
            for k in ('recurAfterDue', 'recurAfterWait', 'recurTaskUntil'):
                Column(k)

            # UDA date/time entry.  TODO Make these dynamic.
            Column('reviewed', datetime.datetime.fromisoformat, cls.datetime_pre_dump)

        return cls._by_name[name]


# TODO: work out a way to provide caching given @functools.cache doesn't work
# because dict[str, str] isn't hashable.
def temp_environ(env_ext: dict[str, str]) -> dict[str, str]:
    env = os.environ.copy()
    env.update(env_ext)
    return env


# Based on https://github.com/JensErat/task-relative-recur/blob/master/on-modify.relative-recur
def tw_calc(statement: str, env_ext: Optional[dict[str, str]]=None) -> str:
    env: Optional[dict[str, str]]
    if env_ext is None:
        env = None
    else:
        env = temp_environ(env_ext)

    p = subprocess.run(['task', 'rc.verbose=nothing',
                        'rc.date.iso=yes', 'calc', statement], env=env,
                       stdout=subprocess.PIPE, check=True, encoding='utf-8')
    return p.stdout.rstrip()


def tw_calc_datetime(statement: str, env_ext: Optional[dict[str, str]]=None) -> datetime.datetime:
    calc_str = tw_calc(statement, env_ext)
    return datetime.datetime.fromisoformat(calc_str)


def tw_calc_bool(statement: str, env_ext: Optional[dict[str, str]]=None) -> bool:
    calc_str = tw_calc(statement, env_ext)
    if calc_str == 'true':
        return True
    if calc_str == 'false':
        return False
    raise RuntimeError(f"{calc_str:r} neither 'false' nor 'true'")


@dataclass
class Task(collections.abc.MutableMapping):
    d: dict

    @classmethod
    def json_decoder(cls, obj):
        d = {}
        for key in obj:
            c = Column.by_name(key)
            if c.json_decoder is None:
                d[key] = obj[key]
            else:
                d[key] = c.json_decoder(obj[key])
        return cls(d)

    def __getitem__(self, key):
        try:
            return self.d[key]
        except KeyError:
            try:
                return self.d[key.name]
            except (KeyError, AttributeError):
                if key == 'uuid' or key == Column.by_name('uuid'):
                    self.gen_uuid()
                    return self['uuid']
                raise KeyError(repr(key))

    def gen_uuid(self):
        self['uuid'] = uuid.uuid4()

    def gen_missing_uuid(self):
        try:
            self.d['uuid']
        except KeyError:
            self.gen_uuid()

    def __setitem__(self, key, value) -> None:
        if isinstance(key, Column):
            key = key.name
        self.d[key] = value

    def __delitem__(self, key) -> None:
        if isinstance(key, Column):
            key = key.by_name
        del self.d[key]

    def __iter__(self):
        return iter(self.d)

    def __len__(self) -> int:
        return len(self.d)

    def duplicate(self) -> 'Task':
        new_task = self.__class__(deepcopy(self.d))
        del new_task['uuid']
        return new_task

    def get_pre_json(self, key):
        if isinstance(key, str):
            key = Column.by_name(key)
        if key.json_pre_dump is None:
            return self[key]
        return key.json_pre_dump(self[key])

    def get_json(self, key):
        return json.dumps(self.get_pre_json(key))


class TaskEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Task):
            d = {}
            for key in obj:
                column = Column.by_name(key)
                if column.json_pre_dump is None:
                    d[key] = obj[key]
                else:
                    d[key] = column.json_pre_dump(obj[key])
            return d
        return super().default(self, obj)


def tw_import(tasks: Union[Task, Iterable[Task]]) -> None:
    subprocess.run(['task', 'rc.verbose=nothing', 'import', '-'], input=json.dumps(tasks, cls=TaskEncoder), encoding='utf-8', check=True)


# The shape I'm expecting the hook functions to take.
#
# Hooks return:
# - The return code
# - For on-add/on-modify hooks, the task to be added/modified; required if the
#   return code is 0, optional otherwise (since it'll be ignored by
#   TaskWarrior).
# - A one-line feedback string; required if the return code is not 0, optional
#   otherwise.
# - An optional post-hook action, which will be called after TaskWarrior exits
#   and can do things like creating new follow-up tasks
PostHookAction: TypeAlias = Callable[[], Any]
OnAddHook: TypeAlias = Callable[[Task], tuple[int, Optional[Task], Optional[str], Optional[PostHookAction]]]
OnModifyHook: TypeAlias = Callable[[Task, Task], tuple[int, Optional[Task], Optional[str], Optional[PostHookAction]]]
BareHook: TypeAlias = Callable[[], tuple[int, Optional[str], Optional[PostHookAction]]]
OnLaunchHook = OnExitHook = BareHook

def on_add(hooks: Iterable[OnAddHook]) -> NoReturn:
    task = json.loads(sys.stdin.readline(), object_hook=Task.json_decoder)

    feedback_messages = []
    final_tasks = []
    for hook in hooks:
        if DEBUG:
            sprint(f'Pre-add hook: {task=!r}, {hook=!r}')
        rc, task, feedback, final = hook(task)
        if DEBUG:
            sprint(f'Hook result: {rc=!r}, {task=!r}, {feedback=!r}, {final=!r}')
        assert task is not None or (rc != 0 and feedback is not None)
        if rc != 0:
            print('{}')
            print(feedback)
            sys.exit(rc)
        if feedback is not None:
            feedback_messages.append(feedback)
        if final is not None:
            final_tasks.append(final)

    if DEBUG:
        sprint(f'Done: {task=!r}, {feedback_messages=!r}')
    print(json.dumps(task, cls=TaskEncoder))
    print('; '.join(feedback_messages))

    do_final_tasks(final_tasks)


def on_modify(hooks: Iterable[OnModifyHook]) -> NoReturn:
    old_task = json.loads(sys.stdin.readline(), object_hook=Task.json_decoder)
    task = json.loads(sys.stdin.readline(), object_hook=Task.json_decoder)

    feedback_messages = []
    final_tasks = []
    for hook in hooks:
        if DEBUG:
            sprint(f'Pre-modify hook: {task=!r}, {hook=!r}')
        rc, task, feedback, final = hook(old_task, task)
        if DEBUG:
            sprint(f'Hook result: {rc=!r}, {task=!r}, {feedback=!r}, {final=!r}')
        assert task is not None or (rc != 0 and feedback is not None)
        if rc != 0:
            print('{}')
            print(feedback)
            sys.exit(rc)
        if feedback is not None:
            feedback_messages.append(feedback)
        if final is not None:
            final_tasks.append(final)

    if DEBUG:
        sprint(f'Done: {task=!r}, {feedback_messages=!r}')
    print(json.dumps(task, cls=TaskEncoder))
    print('; '.join(feedback_messages))

    do_final_tasks(final_tasks)


def on_launch_or_exit(hooks: Iterable[BareHook]) -> NoReturn:
    feedback_messages = []
    final_tasks = []
    for hook in hooks:
        if DEBUG:
            sprint(f'Pre-bare hook: {hook=!r}')
        rc, feedback, final = hook()
        if DEBUG:
            sprint(f'Hook result: {rc=!r}, {feedback=!r}, {final=!r}')
        assert rc == 0 or feedback is not None
        if rc != 0:
            print(feedback)
            sys.exit(rc)
        if feedback is not None:
            feedback_messages.append(feedback)
        if final is not None:
            final_tasks.append(final)

    if DEBUG:
        sprint(f'Done: {feedback_messages=!r}')
    print('; '.join(feedback_messages))

    do_final_tasks(final_tasks)


def do_final_tasks(tasks: Iterable[PostHookAction]) -> NoReturn:
    if DEBUG:
        sprint(f'Pre-fork: {tasks=!r}')

    if tasks:
        sys.stdout.flush()

        if (0 < os.fork()):
            sys.exit(0)

        try:
            # TaskWarrior waits for this process to close stdout, so do that.
            os.close(sys.stdout.fileno())
        except OSError as ex:
            # Apparently this sometimes produces an error, possibly because
            # stdout has already been closed!?  I want to see if/when this
            # happens!
            sprint(f'Temporary OSError info: f{ex=!r}')

        psutil.Process().parent().wait()

        for task in tasks:
            if DEBUG:
                sprint(f'Task: {task=!r}')
            task()

    sys.exit(0)


def due_end_of(task1: Task, task2: Optional[Task]=None) -> tuple[Literal[0], Task, Optional[str], None]:
    if task2 is None:  # On-add hook
        task = task1
    else:  # On-modify hook
        task = task2

    if task['status'] == 'recurring':
        # Don't modify recurring tasks; they'll get fixed when the individual
        # instances are created.
        return 0, task, None, None

    try:
        due_date = task['due'].astimezone()
    except KeyError:
        return 0, task, None, None

    if due_date.time() == datetime.time():
        task['due'] = due_date - datetime.timedelta(seconds=1)
        return 0, task, f'Changed due from {due_date.isoformat()} to {task["due"].isoformat()}', None

    return 0, task, None, None


def recur_after(task1: Task, task2: Optional[Task]=None) -> tuple[Literal[0], Task, Optional[str], Optional[PostHookAction]]:
    if task2 is None:  # On-add hook
        task = task1
        if task['status'] != 'completed':
            # Not a new completed task, so nothing to do.
            return 0, task, None, None
    else:  # On-modify hook
        old_task, task = task1, task2
        if task['status'] != 'completed' or old_task['status'] == 'completed':
            # Change doesn't include completing the task, so nothing to do.
            return 0, task, None, None

    end_date = task['end']
    wait_delay = task.get('recurAfterWait', None)
    due_delay = task.get('recurAfterDue', None)
    if wait_delay is None and due_delay is None:
        return 0, task, None, None

    new_task = task.duplicate()
    new_task['status'] = 'pending'
    new_task['entry'] = task['end']
    del new_task['modified']
    del new_task['end']

    message_parts = [f'Creating new task {task["description"]}']
    if wait_delay:
        new_task['wait'] = tw_calc_datetime(task.get_pre_json('end') + ' + ' + wait_delay).astimezone()
        message_parts.append(f'waiting until {new_task["wait"].isoformat()}')
    if due_delay:
        new_task['due'] = tw_calc_datetime(task.get_pre_json('end') + ' + ' + due_delay).astimezone()
        message_parts.append(f'due {new_task["due"].isoformat()}')

    return 0, task, ', '.join(message_parts), functools.partial(tw_import, new_task)


def child_until(task1: Task, task2: Optional[Task]=None) -> tuple[int, Optional[Task], Optional[str], None]:
    if task2 is None:  # On-add hook
        task = task1
    else:  # On-modify hook
        task = task2

    if task['status'] == 'recurring':
        return 0, task, None, None

    due = task.get('due', None)
    child_until = task.get('recurTaskUntil', None)

    if child_until is None:
        return 0, task, None, None

    if due is None and child_until is not None:
        return 1, None, f'Task {task["uuid"]} with recurTaskUntil but without due date', None

    old_until = task.get('until', None)
    task['until'] = tw_calc_datetime(task.get_pre_json('due') + ' + ' + child_until).astimezone()

    if old_until is None:
        return 0, task, f'Task {task["description"]} expires {task["until"].isoformat()}', None
    if old_until == task['until']:
        return 0, task, None, None
    return 0, task, f'Task {task["description"]} did expire {old_until.isoformat()}, now expires {task["until"].isoformat()}', None


def inbox(task: Task) -> tuple[Literal[0], Task, Optional[str], None]:
    if 'tags' in task or 'project' in task:
        return 0, task, None, None
    task['tags'] = ['inbox']
    return 0, task, f'Tagged {task["description"]} as inbox', None
