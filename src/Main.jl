module Untangle
using Gtk, Cairo, Random

# Chargement des sous-modules (ordre important : les dépendances en premier)
include("types.jl")        # structures de données
include("geometry.jl")     # calculs de croisement (dépend de types)
include("generator.jl")    # génération du graphe (dépend de geometry)
include("render.jl")       # affichage Cairo (dépend de geometry)
include("input.jl")        # interactions souris (dépend de types)

# ── Constantes globales du jeu ───────────────────────────────────────
const W       = 800   # largeur de la fenêtre en pixels
const H       = 600   # hauteur de la fenêtre en pixels
const R       = 14.0  # rayon d'un nœud en pixels 
const N_NODES = 8     # nombre de nœuds dans le graphe
const N_EDGES = 11    # nombre d'arêtes dans le graphe

export run_game
"""
    pick_node(state, x, y; radius, tolerance)

Cherche un nœud dont le centre est à distance ≤ `radius + tolerance`
du point (x, y). Retourne son index ou `nothing`.

Si plusieurs nœuds sont sous le curseur (superposition), on sélectionne
le dernier (affiché au-dessus), ce qui est l'attente habituelle de l'utilisateur.
"""
function pick_node(state::GameState, x::Real, y::Real;
                   radius::Real = 14, tolerance::Real = 4)
    distance = √((x - node.x)² + (y - node.y)²)
    result = nothing
    for i in 1:length(state.nodes)
        n = state.node[i]
        if distance <= radius + tolerance
            result = i
        end
    end
    return result
end

"""
function on_press(state::GameState, x, y, canvas) # x et y positions du clic de la souris
    for (i, noeud) in enumerate(state.nodes) # on parcourt tous les noeuds dans enumerate et pour chaque noeud, on a le noeud lui-même et son numéro
        if hypot(noeud.x - x, noeud.y - y) <= R + 4 # hypot est une fonction de julia qui calcule la distance entre 2 points 
                                                    # ici, on cherche la distance entre le centre du noeud et la position de la souris,
                                                    # si cette distance est inférieure ou égale au rayon du noeud (=R) plus une marge de 4 pixels,
                                                    # alors on considère que le noeud a été cliqué
            state.dragging = i # on mémorise le numéro du nœud qu'on est en train d'attraper
            state.drag_ox  = x - noeud.x # on mémorise le décalage entre la souris et le centre du nœud, en horizontal (ox) et vertical (oy).
            state.drag_oy  = y - noeud.y # noeud.x et noeud.y sont les coordonnées du centre du nœud et x,y sont les coordonnées de la souris au moment du clic
            break # quand on a trouvé un noeud assez proche de la souris, on arrête de chercher un autre noeud
        end
    end
end

function on_move!(state::GameState, x, y, canvas)
    state.dragging === nothing && return # si on a pas de noeud sélectionné, on ne fait rien, le state.dragging vient d'en haut, c'est le numéro du noeud sélectionné
    noeud = state.nodes[state.dragging] # on récupère le nœud qu'on est en train de déplacer, grâce à son numéro mémorisé dans state.dragging
    noeud.x = clamp(x - state.drag_ox, R, W - R) # clamp est une fonction de Julia. clamp(x,y,z) avec x la valeur à limiter, y la limite inférieure et z la limite supérieure
    noeud.y = clamp(y - state.drag_oy, R, H - R) # le -state.drag_ox et -state.drag_oy permettent de maintenir le même décalage entre la souris et le centre du nœud
                                                 # pendant le déplacement, pour que le nœud ne "saute" pas sous la souris. Donc pour sélectionner un noeud, on ne doit pas
                                                 # cliquer exactement dessus, et le decalage que l'on crée est conservé pendant le déplacement
    draw(canvas) # on redessine pour voir le déplacement du noeud
end

function on_release!(state::GameState, canvas)
    state.dragging = nothing # la fonction on_release permet de relacher le nœud qu'on était en train de déplacer, en mettant state.dragging à nothing
    draw(canvas)
end  

"""
    run_game()

Point d'entrée : crée la fenêtre, génère un graphe, branche les
callbacks souris et lance la boucle GTK.
"""
function run_game()
    # 1) État initial du jeu
    state = GameState()
    generate!(state, N_NODES, width = W, height = H, radius = R)

    # 2) Fenêtre + canvas
    fenêtre    = GtkWindow("Untangle", W, H)
    canvas = GtkCanvas(W, H)
    push!(fenêtre, canvas)

    # 3) Callback de dessin (appelé à chaque redraw)
    @guarded draw(canvas) do c
        ctx = getgc(c)
        render(ctx, state; radius = R)
    end

    # 4) Callbacks souris
    canvas.mouse.button1press = (w, e) -> # e = évenement souris
        on_press!(state, e.x, e.y, canvas; radius = R)

    canvas.mouse.motion = (w, e) ->
        on_move!(state, e.x, e.y, canvas;width  = W, height = H, radius = R)

    canvas.mouse.button1release = (w, e) ->
        on_release!(state, canvas)

    # 5) Affichage + boucle principale
    showall(fenêtre)
    signal_connect(fenêtre, :destroy) do _
        Gtk.gtk_quit()
    end
    Gtk.gtk_main()
end

end # module Untangle
