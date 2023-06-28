import subprocess
import json
import re
import datetime
from typing import Union, Callable, NoReturn, TypeVar, Optional, TypeAlias, ClassVar, Any, Literal, Self, TypeGuard, TypedDict, NotRequired
from collections.abc import Iterable, Iterator
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

BaseJsonValue: TypeAlias = Union[dict[str, 'BaseJsonValue'],
                                 list['BaseJsonValue'],
                                 str, int, float, bool, None]
TaskJsonValue: TypeAlias = Union[dict[str, 'TaskJsonValue'],
                                 list['TaskJsonValue'], 'Task',
                                 str, int, float, bool, None]

U = TypeVar('U')
V = TypeVar('V')

def list_map(f: Callable[[U], V]) -> Callable[[Iterable[U]], list[V]]:
    return lambda x: list(map(f, x))

@dataclass(frozen=True)
class Column:
    name: str
    json_decoder: Optional[Callable[[BaseJsonValue], Any]] = None  # TODO fixup typing
    json_pre_dump: Optional[Callable[[Any], BaseJsonValue]] = None
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
            Column('parent', uuid.UUID, str)
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


def tw_add(args: list[str],
           entry: Optional[datetime.datetime] = None,
           extra_tags: Optional[Iterable[str]] = None,
           env_ext: Optional[dict[str, str]] = None) -> uuid.UUID:
    '''Add a task using the command line interface for setting properties.'''
    if entry is not None:
        args.append('entry:' + Column.datetime_pre_dump(entry))

    if extra_tags is not None:
        args.extend(f'+{tag}' for tag in extra_tags)

    env: Optional[dict[str, str]]
    if env_ext is None:
        env = None
    else:
        env = temp_environ(env_ext)

    print(f'{args=!r}')
    p = subprocess.run(['task', 'rc.verbose=new-uuid', 'add'] + args, env=env,
                       stdout=subprocess.PIPE, check=True, encoding='utf-8')

    new_uuid: Optional[uuid.UUID] = None
    for line in p.stdout.split('\n'):
        if line.startswith('Created task ') and line.endswith('.'):
            if new_uuid is not None:
                ex = RuntimeError('Unexpectedly multiple task UUIDs in "task add" output')
                ex.add_note(p.stdout)
                raise ex
            new_uuid = uuid.UUID(line.removeprefix('Created task ').removesuffix('.'))
    if new_uuid is None:
        ex = RuntimeError('Unexpectedly no tasks UUIDs in "task add" output')
        ex.add_note(p.stdout)
        raise ex

    return new_uuid


@dataclass
class Task(collections.abc.MutableMapping[str, Any]):  # TODO fixup typing?
    d: dict[str, Any]

    @classmethod
    def json_decoder(cls, obj: dict[str, BaseJsonValue]) -> Self:
        d = {}
        for key in obj:
            c = Column.by_name(key)
            if c.json_decoder is None:
                d[key] = obj[key]
            else:
                d[key] = c.json_decoder(obj[key])
        return cls(d)

    def __getitem__(self, key: str | Column) -> Any:
        try:
            if isinstance(key, str):
                return self.d[key]
            else:
                return self.d[key.name]
        except KeyError:
            if key == 'uuid' or key == Column.by_name('uuid'):
                self.gen_uuid()
                return self['uuid']
            raise

    def gen_uuid(self) -> None:
        self['uuid'] = uuid.uuid4()

    def gen_missing_uuid(self) -> None:
        try:
            self.d['uuid']
        except KeyError:
            self.gen_uuid()

    def __setitem__(self, key: str | Column, value: Any) -> None:
        if isinstance(key, Column):
            key = key.name
        self.d[key] = value

    def __delitem__(self, key: str | Column) -> None:
        if isinstance(key, Column):
            key = key.name
        del self.d[key]

    def __iter__(self) -> Iterator[str]:
        return iter(self.d)

    def __len__(self) -> int:
        return len(self.d)

    def duplicate(self) -> Self:
        new_task = self.__class__(deepcopy(self.d))
        del new_task['uuid']
        return new_task

    def get_pre_json(self, key: str | Column) -> BaseJsonValue:
        if isinstance(key, str):
            key = Column.by_name(key)
        if key.json_pre_dump is None:
            value = self[key]
            assert is_base_json_value(value)
            return value
        return key.json_pre_dump(self[key])

    def get_json(self, key: str | Column) -> str:
        return json.dumps(self.get_pre_json(key))

    def identifier(self) -> str:
        try:
            ident = self['id']
        except KeyError:
            pass
        else:
            if ident != 0:
                return str(ident)

        # Either there is no ID number at all, or the ID number is the fake
        # value "0".  In either case, return the first part of the UUID
        # instead.  This will generate a UUID if one doesn't exist already.
        return str(self['uuid']).split('-', maxsplit=1)[0]


class TaskEncoder(json.JSONEncoder):
    def default(self, obj: object) -> Any:  # TODO fixup typing
        if isinstance(obj, Task):
            d = {}
            for key in obj:
                column = Column.by_name(key)
                if column.json_pre_dump is None:
                    d[key] = obj[key]
                else:
                    d[key] = column.json_pre_dump(obj[key])
            return d
        return super().default(obj)


def tw_import(tasks: Union[Task, Iterable[Task]]) -> None:
    subprocess.run(['task', 'rc.verbose=nothing', 'import', '-'], input=json.dumps(tasks, cls=TaskEncoder), encoding='utf-8', check=True)


def is_list_of_tasks(v: Any) -> TypeGuard[list[Task]]:
    return isinstance(v, list) and all(map(lambda t: isinstance(t, Task), v))


def tw_export(filter_args: Optional[list[str]] = None,
              env_ext: Optional[dict[str, str]] = None) -> list[Task]:
    if filter_args is None:
        filter_args = []

    env: Optional[dict[str, str]]
    if env_ext is None:
        env = None
    else:
        env = temp_environ(env_ext)

    p = subprocess.run(['task', 'rc.verbose=none'] + filter_args + ['export'],
                       env=env, stdout=subprocess.PIPE, check=True,
                       encoding='utf-8')
    decoded = decode_string(p.stdout)
    assert is_list_of_tasks(decoded)
    return decoded


def annotate(task_uuid: uuid.UUID, annotation: str,
             entry: Optional[datetime.datetime]) -> None:
    annotation_obj: dict[str, Union[str, datetime.datetime]] = {'description': annotation}
    if entry is not None:
        annotation_obj['entry'] = entry

    task = tw_export([str(task_uuid)])[0]

    if 'annotations' in task:
        task['annotations'].append(annotation_obj)
    else:
        task['annotations'] = [annotation_obj]

    tw_import(task)


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
PostHookAction: TypeAlias = Callable[[], Any]  # TODO fixup typing
HookResult: TypeAlias = tuple[int, Optional[Task], Optional[str], Optional[PostHookAction]]
OnAddHook: TypeAlias = Callable[[Task], HookResult]
OnModifyHook: TypeAlias = Callable[[Task, Task], HookResult]
BareHook: TypeAlias = Callable[[], tuple[int, Optional[str], Optional[PostHookAction]]]
OnLaunchHook = OnExitHook = BareHook

def on_add(hooks: Iterable[OnAddHook]) -> NoReturn:
    task = json.loads(sys.stdin.readline(), object_hook=Task.json_decoder)

    feedback_messages = []
    final_jobs = []
    for hook in hooks:
        if DEBUG:
            sprint(f'Pre-add hook: {task=!r}, {hook=!r}')
        rc, task, feedback, final = hook(task)
        if DEBUG:
            sprint(f'Hook result: {rc=!r}, {task=!r}, {feedback=!r}, {final=!r}')
        assert task is not None or (rc != 0 and feedback is not None)
        if rc != 0:
            print(feedback)
            sys.exit(rc)
        if feedback is not None:
            feedback_messages.append(feedback)
        if final is not None:
            final_jobs.append(final)

    if DEBUG:
        sprint(f'Done: {task=!r}, {feedback_messages=!r}')
    print(json.dumps(task, cls=TaskEncoder))
    print('; '.join(feedback_messages))

    do_final_jobs(final_jobs)


def on_modify(hooks: Iterable[OnModifyHook]) -> NoReturn:
    orig_task = json.loads(sys.stdin.readline(), object_hook=Task.json_decoder)
    changed_task = json.loads(sys.stdin.readline(), object_hook=Task.json_decoder)

    feedback_messages = []
    final_jobs = []
    for hook in hooks:
        if DEBUG:
            sprint(f'Pre-modify hook: {changed_task=!r}, {hook=!r}')
        rc, changed_task, feedback, final = hook(changed_task, orig_task)
        if DEBUG:
            sprint(f'Hook result: {rc=!r}, {changed_task=!r}, {feedback=!r}, {final=!r}')
        assert changed_task is not None or (rc != 0 and feedback is not None)
        if rc != 0:
            print('{}')
            print(feedback)
            sys.exit(rc)
        if feedback is not None:
            feedback_messages.append(feedback)
        if final is not None:
            final_jobs.append(final)

    if DEBUG:
        sprint(f'Done: {changed_task=!r}, {feedback_messages=!r}')
    print(json.dumps(changed_task, cls=TaskEncoder))
    print('; '.join(feedback_messages))

    do_final_jobs(final_jobs)


def on_launch_or_exit(hooks: Iterable[BareHook]) -> NoReturn:
    feedback_messages = []
    final_jobs = []
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
            final_jobs.append(final)

    if DEBUG:
        sprint(f'Done: {feedback_messages=!r}')
    print('; '.join(feedback_messages))

    do_final_jobs(final_jobs)


def do_final_jobs(jobs: Iterable[PostHookAction]) -> NoReturn:
    if DEBUG:
        sprint(f'Pre-fork: {jobs=!r}')

    if jobs:
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
            sprint(f'Temporary OSError info: {ex=!r}')

        psutil.Process().parent().wait()

        for job in jobs:
            if DEBUG:
                sprint(f'Job: {job=!r}')
            job()

    sys.exit(0)


def due_end_of(changed_task: Task, orig_task: Optional[Task]=None) -> tuple[Literal[0], Task, Optional[str], None]:
    if changed_task['status'] == 'recurring':
        # Don't modify recurring tasks; they'll get fixed when the individual
        # instances are created.
        return 0, changed_task, None, None

    try:
        due_date = changed_task['due'].astimezone()
    except KeyError:  # No due date
        return 0, changed_task, None, None

    if due_date.time() == datetime.time():
        changed_task['due'] = due_date - datetime.timedelta(seconds=1)
        return 0, changed_task, f'Changed due from {due_date.isoformat()} to {changed_task["due"].isoformat()}', None

    return 0, changed_task, None, None


def recur_after(changed_task: Task, orig_task: Optional[Task]=None) -> tuple[Literal[0], Task, Optional[str], Optional[PostHookAction]]:
    if changed_task['status'] == 'completed' and (
            orig_task is None or orig_task['status'] != 'completed'):
        # Either a brand new task that's started as completed, or an existing
        # task that has changed to being completed, so this check should run.

        wait_delay = changed_task.get('recurAfterWait', None)
        due_delay = changed_task.get('recurAfterDue', None)
        if wait_delay is None and due_delay is None:
            return 0, changed_task, None, None

        new_task = changed_task.duplicate()
        new_task['status'] = 'pending'
        new_task['entry'] = changed_task['end']
        del new_task['modified']
        del new_task['end']

        message_parts = [f'Creating new task {new_task["description"]}']
        end_as_str = changed_task.get_pre_json('end')
        assert isinstance(end_as_str, str)
        if wait_delay:
            new_task['wait'] = tw_calc_datetime(end_as_str + ' + ' + wait_delay).astimezone()
            message_parts.append(f'waiting until {new_task["wait"].isoformat()}')
        if due_delay:
            new_task['due'] = tw_calc_datetime(end_as_str + ' + ' + due_delay).astimezone()
            message_parts.append(f'due {new_task["due"].isoformat()}')

        return 0, changed_task, ', '.join(message_parts), functools.partial(tw_import, new_task)
    return 0, changed_task, None, None


def child_until(changed_task: Task, orig_task: Optional[Task]=None) -> tuple[int, Optional[Task], Optional[str], None]:
    if changed_task['status'] == 'recurring':
        return 0, changed_task, None, None

    due = changed_task.get('due', None)
    child_until = changed_task.get('recurTaskUntil', None)

    if child_until is None:
        return 0, changed_task, None, None
    assert isinstance(child_until, str)

    if due is None and child_until is not None:
        return 1, None, f'Task {changed_task.identifier()} with recurTaskUntil but without due date', None

    old_until = changed_task.get('until', None)
    due_as_str = changed_task.get_pre_json('due')
    assert isinstance(due_as_str, str)
    changed_task['until'] = tw_calc_datetime(due_as_str + ' + ' + child_until).astimezone()

    if old_until is None:
        return 0, changed_task, f'Task "{changed_task["description"]}" expires {changed_task["until"].isoformat()}', None
    if old_until == changed_task['until']:
        return 0, changed_task, None, None
    return 0, changed_task, f'Task "{changed_task["description"]}" did expire {old_until.isoformat()}, now expires {changed_task["until"].isoformat()}', None


# I want all tasks to have a reviewed date, as I want tasks that have never
# been reviewed to be higher on the to-review list than tasks that have been
# reviewed albeit a while ago.
#
# For some reason, times before 2001-09-09T01:46:40Z seem to get treated as
# equivalent to no time being set at all, so choose an arbitrary time after
# then.
def reviewed(task: Task) -> tuple[Literal[0], Task, None, None]:
    if 'reviewed' in task:
        return 0, task, None, None
    task['reviewed'] = datetime.datetime(2002, 1, 1)
    return 0, task, None, None


def inbox(task: Task) -> tuple[Literal[0], Task, Optional[str], None]:
    if 'tags' in task or 'project' in task:
        return 0, task, None, None
    task['tags'] = ['inbox']
    return 0, task, f'Tagged {task["description"]} as inbox', None

def is_task_json_value(v: Any) -> TypeGuard[TaskJsonValue]:
    if isinstance(v, dict):
        return all(isinstance(key, str) and is_task_json_value(value) for key, value in v.items())
    if isinstance(v, list):
        return all(map(is_task_json_value, v))
    if (isinstance(v, Task) or isinstance(v, str) or isinstance(v, int) or
            isinstance(v, float) or isinstance(v, bool) or v is None):
        return True
    return False


def is_base_json_value(v: Any) -> TypeGuard[BaseJsonValue]:
    if isinstance(v, dict):
        return all(isinstance(key, str) and is_base_json_value(value) for key, value in v.items())
    if isinstance(v, list):
        return all(map(is_base_json_value, v))
    if (isinstance(v, str) or isinstance(v, int) or isinstance(v, float) or
            isinstance(v, bool) or v is None):
        return True
    return False


def decode_string(string: str) -> TaskJsonValue:
    decoded = json.loads(string, object_hook=Task.json_decoder)
    assert is_task_json_value(decoded)
    return decoded
