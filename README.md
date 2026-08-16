# PropSystem prototype

A minimal, server-authoritative Roblox prop interaction loop. Tagged physical objects can be inspected, grabbed at the cursor hit point, carried with mass-dependent responsiveness, released, anchored, damaged, and broken.

## Create a prop

1. Add the CollectionService tag `Prop` to a `BasePart` (or a `Model` with a primary part).
2. Set the attributes `AssetKey` (string), `MaxHealth` (number), and `Mass` (number).
3. Ensure movable props are unanchored.

Runtime attributes (`ObjectID`, `Health`, and `PropState`) are assigned by the server. Use `PropService:Damage(instance, amount)` from server code to damage a prop.

## Controls

- **E** — grab the aimed prop or release the held prop
- **F** — anchor or unanchor the aimed prop
- **Mouse wheel** — pull a held prop closer or push it farther away
- **B** — enter or leave build mode
- **Left click** — place the build-mode preview
- **Right click** — cancel the current preview
- **R / T / Y** — rotate the preview on its Y / X / Z axis in 15-degree steps

## Plots and building

Use `!pc` to create one temporary 100-stud cube plot centered on your character
and snapped to whole studs. Plots cannot overlap. `!rmp` removes your plot and
only builds and claimed props that belong to it. Plot data is intentionally not
saved in this prototype.

The owner can grant another online player build permission with `!pt name`,
revoke it with `!ptr name`, or clear all permissions with `!ptr all`. Trust is
tracked by user ID. Owners and trusted players can anchor props or place walls,
floors, ramps, and foundations inside the plot. Build previews and plot boundaries
are local; the server independently validates permissions, range, containment,
snapping, overlap, type, and plot limits before creating a structure.

Grabs use the cursor's surface hit point with a small amount of validation
tolerance for cursor and network drift. Server-created attachments and
limited-force constraints pull that point toward a target 2–3 studs in front of
the player, rotating the prop along with the player; props are never teleported.
Held props do not collide with their holder, preventing character-launching
physics feedback. Multiple players can grab different points on the same prop,
and every additional constraint contributes force.

Carrying locks the local player to first person. Camera pitch raises or lowers
the physical target (with ground and vertical clamps). The holder renders a local
R6 carry arm every frame for smooth motion and hides their replicated copy; other
players see the server-authoritative carry arm at the same grip point.
The server ends the grip if that shoulder-to-grip distance exceeds 4.5 studs.

Props whose `Classification` attribute is `"Heavy"`, whose `Heavy` attribute is
true, or whose mass meets `HeavyMass` try to use both arms. Heavy props also reduce
WalkSpeed progressively as their mass approaches `HeavyMaxSlowMass`.

When a tool is equipped, newly grabbed props use only the R6 left hand so the tool
can remain in its default right hand. Equipping a tool during a two-handed carry
removes only the right arm; a right-only carry is released.

## Development

The repository uses a Rojo project layout. Build a place file with:

```sh
rojo build -o PropSystem.rbxlx
```
